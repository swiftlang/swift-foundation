//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

/// A structure designed to parse URLs based on RFC 3986 and to construct URLs from their constituent parts.
///
/// You can easily obtain a `URL` based on the contents of a `URLComponents` or vice versa.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct URLComponents: Hashable, Equatable, Sendable {
    var components: _URLComponents

    internal enum InvalidComponentError: Error {
        case scheme
        case user
        case password
        case host
        case port
        case path
        case query
        case queryItem
        case fragment
    }

    internal enum Component {
        case scheme
        case user
        case password
        case host
        case port
        case path
        case query
        case queryItem
        case fragment
    }

    internal struct _URLComponents: Sendable {

        typealias Parser = RFC3986Parser

        /// Non-nil if the components were initialized from a string, which is parsed into a `URLParseInfo`.
        private var urlParseInfo: URLParseInfo?
        private var parseInfoIsValidForAllRanges:   Bool = true
        private var parseInfoIsValidForScheme:      Bool = true
        private var parseInfoIsValidForUser:        Bool = true
        private var parseInfoIsValidForPassword:    Bool = true
        private var parseInfoIsValidForHost:        Bool = true
        private var parseInfoIsValidForPort:        Bool = true
        private var parseInfoIsValidForPath:        Bool = true
        private var parseInfoIsValidForQuery:       Bool = true
        private var parseInfoIsValidForFragment:    Bool = true

        /// Non-nil if that component was set directly (e.g. `components.scheme = "http"`).
        /// If non-nil, the string will always be valid and properly encoded.  The public computed vars
        /// (non-underscored) first check these underlying stores if present, then check the `urlParseInfo`.
        private var _scheme: String?
        private var _user: String?
        private var _password: String?
        private var _host: String?
        private var _port: Int?
        private var _path: String?
        private var _query: String?
        private var _fragment: String?

        /// True if host was percent-encoded instead of IDNA-encoded.
        private var didPercentEncodeHost: Bool = false

        /// If IDNA-encoding fails to create a valid host string, set this
        /// to `true` to force `.string` and `.url` to return `nil`.
        private var didSetInvalidHost: Bool = false

        init() {
            parseInfoIsValidForAllRanges    = false
            parseInfoIsValidForScheme       = false
            parseInfoIsValidForUser         = false
            parseInfoIsValidForPassword     = false
            parseInfoIsValidForHost         = false
            parseInfoIsValidForPort         = false
            parseInfoIsValidForPath         = false
            parseInfoIsValidForQuery        = false
            parseInfoIsValidForFragment     = false
        }

        init?(string: String, encodingInvalidCharacters: Bool = true) {
            guard let parseInfo = Parser.parse(urlString: string, encodingInvalidCharacters: encodingInvalidCharacters) else {
                return nil
            }
            urlParseInfo = parseInfo
            didPercentEncodeHost = parseInfo.didPercentEncodeHost
        }

        init(parseInfo: URLParseInfo) {
            urlParseInfo = parseInfo
            didPercentEncodeHost = parseInfo.didPercentEncodeHost
        }

        /// Resets the given component. When setting any component, we must:
        /// 1) Forget the cached string if present.
        /// 2) Mark the parse info as invalid, meaning its `urlString` can no longer be used for ranges.
        /// 3) Cause the parse info to forget that this component exists by setting its respective range to nil.
        /// Note that other components in the parse info are still valid if their respective range is non-nil.
        private mutating func reset(_ component: Component) {
            parseInfoIsValidForAllRanges = false
            switch component {
            case .scheme:
                parseInfoIsValidForScheme = false
            case .user:
                parseInfoIsValidForUser = false
            case .password:
                parseInfoIsValidForPassword = false
            case .host:
                parseInfoIsValidForHost = false
                didPercentEncodeHost = false
                didSetInvalidHost = false
            case .port:
                parseInfoIsValidForPort = false
            case .path:
                parseInfoIsValidForPath = false
            case .query:
                parseInfoIsValidForQuery = false
            case .queryItem:
                parseInfoIsValidForQuery = false
            case .fragment:
                parseInfoIsValidForFragment = false
            }
        }

        var scheme: String? {
            if let _scheme { return _scheme }
            if parseInfoIsValidForScheme, let scheme = urlParseInfo?.scheme { return String(scheme) }
            return nil
        }

        mutating func setScheme(_ newValue: String?) throws {
            reset(.scheme)
            guard Parser.validate(newValue, component: .scheme) else {
                throw InvalidComponentError.scheme
            }
            _scheme = newValue
            if encodedHost != nil {
                // This resets the host to an appropriate encoding for the given scheme
                let decodedHost = host
                host = decodedHost
            }
        }

        var user: String? {
            get { Parser.percentDecode(percentEncodedUser) }
            set {
                reset(.user)
                if Parser.validate(newValue, component: .user, percentEncodingAllowed: false) {
                    _user = newValue
                    return
                }
                _user = Parser.percentEncode(newValue, component: .user)
            }
        }

        var password: String? {
            get { Parser.percentDecode(percentEncodedPassword) }
            set {
                reset(.password)
                if Parser.validate(newValue, component: .password, percentEncodingAllowed: false) {
                    _password = newValue
                    return
                }
                _password = Parser.percentEncode(newValue, component: .password)
            }
        }

        var host: String? {
            get {
                guard let encodedHost else { return nil }
                guard !encodedHost.isEmpty else { return "" }
                if didPercentEncodeHost {
                    return Parser.percentDecode(encodedHost)
                } else {
                    return Parser.IDNADecodeHost(encodedHost)
                }
            }
            set {
                reset(.host)
                guard let newValue else {
                    _host = nil
                    return
                }
                if Parser.validate(newValue, component: .host) {
                    _host = newValue
                    didPercentEncodeHost = newValue.utf8.contains(UInt8(ascii: "%"))
                    return
                }
                if Parser.shouldPercentEncodeHost(newValue, forScheme: scheme) {
                    guard let percentEncoded = Parser.percentEncode(newValue, component: .host) else {
                        _host = nil
                        didSetInvalidHost = true
                        return
                    }
                    _host = percentEncoded
                    didPercentEncodeHost = true
                    return
                }
                if let idnaEncoded = Parser.IDNAEncodeHost(newValue),
                   Parser.validate(idnaEncoded, component: .host) {
                    _host = idnaEncoded
                    return
                }
                // Even if the IDNA-encoded host is not valid, we need to
                // keep it around to see if a special-cased scheme is set
                // later, telling us to percent-encode it instead.
                // Keep the valid percent-encoded version for now.
                didSetInvalidHost = true
                _host = Parser.percentEncode(newValue, component: .host)
                didPercentEncodeHost = true
            }
        }

        var port: Int? {
            _port ?? (parseInfoIsValidForPort ? urlParseInfo?.port : nil)
        }

        mutating func setPort(_ newValue: Int?) throws {
            reset(.port)
            if let newValue, newValue < 0 {
                throw InvalidComponentError.port
            }
            _port = newValue
        }

        var path: String {
            get { Parser.percentDecode(percentEncodedPath) ?? "" }
            set {
                reset(.path)
                _path = Parser.percentEncode(newValue, component: .path) ?? ""
            }
        }

        var query: String? {
            get { Parser.percentDecode(percentEncodedQuery) }
            set {
                reset(.query)
                if Parser.validate(newValue, component: .query, percentEncodingAllowed: false) {
                    _query = newValue
                    return
                }
                _query = Parser.percentEncode(newValue, component: .query)
            }
        }

        var fragment: String? {
            get { Parser.percentDecode(percentEncodedFragment) }
            set {
                reset(.fragment)
                if Parser.validate(newValue, component: .fragment, percentEncodingAllowed: false) {
                    _fragment = newValue
                    return
                }
                _fragment = Parser.percentEncode(newValue, component: .fragment)
            }
        }

        var percentEncodedUser: String? {
            if let _user { return _user }
            if parseInfoIsValidForUser, let user = urlParseInfo?.user { return String(user) }
            if percentEncodedPassword != nil { return "" }
            return nil
        }

        mutating func setPercentEncodedUser(_ newValue: String?) throws {
            reset(.user)
            guard Parser.validate(newValue, component: .user) else {
                throw InvalidComponentError.user
            }
            _user = newValue
        }

        var percentEncodedPassword: String? {
            if let _password { return _password }
            if parseInfoIsValidForPassword, let password = urlParseInfo?.password { return String(password) }
            return nil
        }

        mutating func setPercentEncodedPassword(_ newValue: String?) throws {
            reset(.password)
            guard Parser.validate(newValue, component: .password) else {
                throw InvalidComponentError.password
            }
            _password = newValue
        }

        var percentEncodedHost: String? {
            if let encodedHost {
                if encodedHost.isEmpty { return "" }
                if didPercentEncodeHost { return encodedHost }
                // Undo any IDNA-encoding and return the percent-encoded version.
                if let decoded = Parser.IDNADecodeHost(encodedHost),
                   let percentEncoded = Parser.percentEncode(decoded, component: .host) {
                    return percentEncoded
                }
            }
            if port != nil || percentEncodedUser != nil { return "" }
            return nil
        }

        mutating func setPercentEncodedHost(_ newValue: String?) throws {
            reset(.host)
            guard let newValue else {
                _host = nil
                return
            }
            guard Parser.validate(newValue, component: .host) else {
                throw InvalidComponentError.host
            }
            didPercentEncodeHost = newValue.utf8.contains(UInt8(ascii: "%"))
            if Parser.shouldPercentEncodeHost(newValue, forScheme: scheme) {
                _host = newValue
                return
            }
            if didPercentEncodeHost {
                guard let decoded = Parser.percentDecode(newValue) else {
                    _host = newValue
                    didSetInvalidHost = true
                    return
                }
                host = decoded
                return
            }
            _host = newValue
        }

        var encodedHost: String? {
            if let _host { return _host }
            if parseInfoIsValidForHost, let host = urlParseInfo?.host { return String(host) }
            if port != nil || percentEncodedUser != nil { return "" }
            return nil
        }

        mutating func setEncodedHost(_ newValue: String?) throws {
            reset(.host)
            guard let newValue else {
                _host = nil
                return
            }
            guard Parser.validate(newValue, component: .host) else {
                throw InvalidComponentError.host
            }
            _host = newValue
            didPercentEncodeHost = newValue.utf8.contains(UInt8(ascii: "%"))
        }

        var percentEncodedPath: String {
            if let _path { return _path }
            if parseInfoIsValidForPath, let path = urlParseInfo?.path { return String(path) }
            return ""
        }

        mutating func setPercentEncodedPath(_ newValue: String) throws {
            reset(.path)
            guard Parser.validate(newValue, component: .path) else {
                throw InvalidComponentError.path
            }
            _path = newValue
        }

        var percentEncodedQuery: String? {
            if let _query { return _query }
            if parseInfoIsValidForQuery, let query = urlParseInfo?.query { return String(query) }
            return nil
        }

        mutating func setPercentEncodedQuery(_ newValue: String?) throws {
            reset(.query)
            guard Parser.validate(newValue, component: .query) else {
                throw InvalidComponentError.query
            }
            _query = newValue
        }

        var percentEncodedFragment: String? {
            if let _fragment { return _fragment }
            if parseInfoIsValidForFragment, let fragment = urlParseInfo?.fragment { return String(fragment) }
            return nil
        }

        mutating func setPercentEncodedFragment(_ newValue: String?) throws {
            reset(.fragment)
            guard Parser.validate(newValue, component: .fragment) else {
                throw InvalidComponentError.fragment
            }
            _fragment = newValue
        }

        var string: String? {
            if parseInfoIsValidForAllRanges { return urlParseInfo?.urlString }
            return computedString
        }

        private var hasAuthority: Bool {
            encodedHost != nil || port != nil || percentEncodedUser != nil || percentEncodedPassword != nil
        }

        private var computedString: String? {
            if didSetInvalidHost { return nil }
            var result = ""
            if let scheme {
                result += "\(scheme):"
            }
            if hasAuthority {
                if let first = percentEncodedPath.utf8.first, first != UInt8(ascii: "/") {
                    return nil
                }
                result += "//"
            } else {
                // If there is no authority, do not allow the path to start with "//",
                // which could be mistaken for the authority separator.
                let pathUTF8 = percentEncodedPath.utf8
                let pathStartsWithDoubleSlash = (
                    pathUTF8.index(after: pathUTF8.startIndex) != pathUTF8.endIndex &&
                    UInt8(ascii: "/") == pathUTF8.first &&
                    UInt8(ascii: "/") == pathUTF8[pathUTF8.index(after: pathUTF8.startIndex)]
                )
                guard !pathStartsWithDoubleSlash else {
                    return nil
                }
            }
            if let percentEncodedUser {
                result += percentEncodedUser
            }
            if let percentEncodedPassword {
                result += ":\(percentEncodedPassword)"
            }
            if percentEncodedUser != nil || percentEncodedPassword != nil {
                result += "@"
            }
            if let encodedHost {
                result += encodedHost
            }
            if let port {
                result += ":\(port)"
            } else if parseInfoIsValidForPort, let portString = urlParseInfo?.portString {
                // The parser already validated a special-case (e.g. addressbook:).
                result += ":\(portString)"
            }
            result += percentEncodedPath
            if let percentEncodedQuery {
                result += "?\(percentEncodedQuery)"
            }
            if let percentEncodedFragment {
                result += "#\(percentEncodedFragment)"
            }
            return result
        }

        func rangeOf(_ component: Component) -> Range<String.Index>? {
            if let urlParseInfo, parseInfoIsValidForAllRanges {
                switch component {
                case .scheme:
                    return urlParseInfo.schemeRange
                case .user:
                    return urlParseInfo.userRange
                case .password:
                    return urlParseInfo.passwordRange
                case .host:
                    return urlParseInfo.hostRange
                case .port:
                    return urlParseInfo.portRange
                case .path:
                    return urlParseInfo.pathRange
                case .query:
                    return urlParseInfo.queryRange
                case .queryItem:
                    return nil
                case .fragment:
                    return urlParseInfo.fragmentRange
                }
            }
            guard let string, let parseInfo = Parser.parse(urlString: string, encodingInvalidCharacters: true) else {
                return nil
            }
            switch component {
            case .scheme:
                return parseInfo.schemeRange
            case .user:
                return parseInfo.userRange
            case .password:
                return parseInfo.passwordRange
            case .host:
                return parseInfo.hostRange
            case .port:
                return parseInfo.portRange
            case .path:
                return parseInfo.pathRange
            case .query:
                return parseInfo.queryRange
            case .queryItem:
                return nil
            case .fragment:
                return parseInfo.fragmentRange
            }
        }

        func queryItems(percentEncoded: Bool) -> [URLQueryItem]? {
            guard let percentEncodedQuery else { return nil }
            guard !percentEncodedQuery.isEmpty else { return [] }
            var result: [URLQueryItem] = []

            let queryUTF8 = percentEncodedQuery.utf8
            var currentIndex = queryUTF8.startIndex
            var itemStartIndex = queryUTF8.startIndex
            var equalSignIndex: String.Index?

            func addItem() {
                // Called when currentIndex is at query item end boundary (either "&" or endIndex).
                var name = ""
                var value: String?
                if let equalSignIndex {
                    name = String(percentEncodedQuery[itemStartIndex..<equalSignIndex])
                    let valueStartIndex = queryUTF8.index(after: equalSignIndex)
                    value = String(percentEncodedQuery[valueStartIndex..<currentIndex])
                } else {
                    name = String(percentEncodedQuery[itemStartIndex..<currentIndex])
                }
                if !percentEncoded {
                    name = Parser.percentDecode(name) ?? ""
                    value = Parser.percentDecode(value)
                }
                result.append(URLQueryItem(name: name, value: value))
            }

            while currentIndex != queryUTF8.endIndex {
                switch queryUTF8[currentIndex] {
                case UInt8(ascii: "="):
                    if equalSignIndex == nil {
                        equalSignIndex = currentIndex
                    }
                case UInt8(ascii: "&"):
                    addItem()
                    itemStartIndex = queryUTF8.index(after: currentIndex)
                    equalSignIndex = nil
                default:
                    break
                }
                currentIndex = queryUTF8.index(after: currentIndex)
            }
            // Add the final query item.
            addItem()
            return result
        }

        mutating func setQueryItems(_ newValue: [URLQueryItem]?) {
            reset(.query)
            guard let newValue else {
                _query = nil
                return
            }
            guard !newValue.isEmpty else {
                _query = ""
                return
            }

            _query = newValue.map { item in
                var itemStr = ""
                if Parser.validate(item.name, component: .queryItem, percentEncodingAllowed: false) {
                    itemStr += item.name
                } else if let percentEncodedName = Parser.percentEncode(item.name, component: .queryItem) {
                    itemStr += percentEncodedName
                }
                guard let value = item.value else {
                    return itemStr
                }
                itemStr += "="
                if Parser.validate(value, component: .queryItem, percentEncodingAllowed: false) {
                    itemStr += value
                } else if let percentEncodedValue = Parser.percentEncode(value, component: .queryItem) {
                    itemStr += percentEncodedValue
                }
                return itemStr
            }.joined(separator: "&")
        }

        mutating func setPercentEncodedQueryItems(_ newValue: [URLQueryItem]?) throws {
            reset(.query)
            guard let newValue else {
                _query = nil
                return
            }
            guard !newValue.isEmpty else {
                _query = ""
                return
            }

            _query = try newValue.map { item in
                guard Parser.validate(item.name, component: .queryItem) else {
                    throw InvalidComponentError.queryItem
                }
                var itemStr = item.name
                if let value = item.value {
                    guard Parser.validate(value, component: .query) else {
                        throw InvalidComponentError.queryItem
                    }
                    itemStr += "=\(value)"
                }
                return itemStr
            }.joined(separator: "&")
        }
    }

    /// Initialize with all components undefined.
    public init() {
        self.components = _URLComponents()
    }

    /// Initialize with the components of a URL.
    ///
    /// If resolvingAgainstBaseURL is `true` and url is a relative URL, the components of url.absoluteURL are used. If the url string from the URL is malformed, nil is returned.
    public init?(url: __shared URL, resolvingAgainstBaseURL resolve: Bool) {
        let string: String
        if resolve {
            string = url.absoluteString
        } else {
            string = url.relativeString
        }
        guard let components = _URLComponents(string: string) else {
            return nil
        }
        self.components = components
    }

    /// Initialize with a URL string.
    ///
    /// If the URLString is malformed, nil is returned.
    public init?(string: __shared String) {
        guard let components = _URLComponents(string: string) else {
            return nil
        }
        self.components = components
    }

    /// Initialize with a URL string and the option to add (or skip) IDNA- and percent-encoding of invalid characters.
    /// If `encodingInvalidCharacters` is false, and the URL string is invalid according to RFC 3986, `nil` is returned.
    /// If `encodingInvalidCharacters` is true, `URLComponents` will try to encode the string to create a valid URL.
    /// If the URL string is still invalid after encoding, `nil` is returned.
    ///
    /// - Parameter string: The URL string.
    /// - Parameter encodingInvalidCharacters: True if `URLComponents` should try to encode an invalid URL string, false otherwise.
    /// - Returns: A `URLComponents` struct for a valid URL, or `nil` if the URL is invalid.
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public init?(string: __shared String, encodingInvalidCharacters: Bool) {
        guard let components = _URLComponents(string: string, encodingInvalidCharacters: encodingInvalidCharacters) else {
            return nil
        }
        self.components = components
    }

    internal init(parseInfo: URLParseInfo) {
        self.components = _URLComponents(parseInfo: parseInfo)
    }

    /// Returns a URL created from the URLComponents.
    ///
    /// If the URLComponents has an authority component (user, password, host or port) and a path component, then the path must either begin with "/" or be an empty string. If the NSURLComponents does not have an authority component (user, password, host or port) and has a path component, the path component must not start with "//". If those requirements are not met, nil is returned.
    public var url: URL? {
        guard let string else { return nil }
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return CFURLCreateWithString(kCFAllocatorDefault, string as CFString, nil) as URL?
        }
        #endif
        return URL(string: string)
    }

    /// Returns a URL created from the URLComponents relative to a base URL.
    ///
    /// If the URLComponents has an authority component (user, password, host or port) and a path component, then the path must either begin with "/" or be an empty string. If the URLComponents does not have an authority component (user, password, host or port) and has a path component, the path component must not start with "//". If those requirements are not met, nil is returned.
    public func url(relativeTo base: URL?) -> URL? {
        guard let string else { return nil }
        guard let base else { return url }
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return CFURLCreateWithString(kCFAllocatorDefault, string as CFString, base as CFURL) as URL?
        }
        #endif
        return URL(string: string, relativeTo: base)
    }

    /// Returns a URL string created from the URLComponents.
    ///
    /// If the URLComponents has an authority component (user, password, host or port) and a path component, then the path must either begin with "/" or be an empty string. If the URLComponents does not have an authority component (user, password, host or port) and has a path component, the path component must not start with "//". If those requirements are not met, nil is returned.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var string: String? {
        components.string
    }

    /// The scheme subcomponent of the URL.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    /// Attempting to set the scheme with an invalid scheme string will cause an exception.
    public var scheme: String? {
        get { components.scheme }
        set {
            do {
                try components.setScheme(newValue)
            } catch {
                fatalError("Attempting to set scheme with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setScheme(_ newValue: String?) throws {
        try components.setScheme(newValue)
    }
#endif

    /// The user subcomponent of the URL.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    ///
    /// Warning: IETF STD 66 (rfc3986) says the use of the format "user:password" in the userinfo subcomponent of a URI is deprecated because passing authentication information in clear text has proven to be a security risk. However, there are cases where this practice is still needed, and so the user and password components and methods are provided.
    public var user: String? {
        get { components.user }
        set { components.user = newValue }
    }

    /// The password subcomponent of the URL.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    ///
    /// Warning: IETF STD 66 (rfc3986) says the use of the format "user:password" in the userinfo subcomponent of a URI is deprecated because passing authentication information in clear text has proven to be a security risk. However, there are cases where this practice is still needed, and so the user and password components and methods are provided.
    public var password: String? {
        get { components.password }
        set { components.password = newValue }
    }

    /// The host subcomponent.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    public var host: String? {
        get { components.host }
        set { components.host = newValue }
    }

    /// The port subcomponent.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    /// Attempting to set a negative port number will cause a fatal error.
    public var port: Int? {
        get { components.port }
        set {
            do {
                try components.setPort(newValue)
            } catch {
                fatalError("Attempting to set port with a negative number")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPort(_ newValue: Int?) throws {
        try components.setPort(newValue)
    }
#endif

    /// The path subcomponent.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    public var path: String {
        get { components.path }
        set { components.path = newValue }
    }

    /// The query subcomponent.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    public var query: String? {
        get { components.query }
        set { components.query = newValue }
    }

    /// The fragment subcomponent.
    ///
    /// The getter for this property removes any percent encoding this component may have (if the component allows percent encoding). Setting this property assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    public var fragment: String? {
        get { components.fragment }
        set { components.fragment = newValue }
    }


    /// The user subcomponent, percent-encoded.
    ///
    /// The getter for this property retains any percent encoding this component may have. Setting this properties assumes the component string is already correctly percent encoded. Attempting to set an incorrectly percent encoded string will cause a `fatalError`. Although ';' is a legal path character, it is recommended that it be percent-encoded for best compatibility with `URL` (`String.addingPercentEncoding(withAllowedCharacters:)` will percent-encode any ';' characters if you pass `CharacterSet.urlUserAllowed`).
    public var percentEncodedUser: String? {
        get { components.percentEncodedUser }
        set {
            do {
                try components.setPercentEncodedUser(newValue)
            } catch {
                fatalError("Attempting to set percentEncodedUser with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPercentEncodedUser(_ newValue: String?) throws {
        try components.setPercentEncodedUser(newValue)
    }
#endif

    /// The password subcomponent, percent-encoded.
    ///
    /// The getter for this property retains any percent encoding this component may have. Setting this properties assumes the component string is already correctly percent encoded. Attempting to set an incorrectly percent encoded string will cause a `fatalError`. Although ';' is a legal path character, it is recommended that it be percent-encoded for best compatibility with `URL` (`String.addingPercentEncoding(withAllowedCharacters:)` will percent-encode any ';' characters if you pass `CharacterSet.urlPasswordAllowed`).
    public var percentEncodedPassword: String? {
        get { components.percentEncodedPassword }
        set {
            do {
                try components.setPercentEncodedPassword(newValue)
            } catch {
                fatalError("Attempting to set percentEncodedPassword with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPercentEncodedPassword(_ newValue: String?) throws {
        try components.setPercentEncodedPassword(newValue)
    }
#endif

    /// The host subcomponent, percent-encoded.
    ///
    /// The getter for this property retains any percent encoding this component may have. Setting this properties assumes the component string is already correctly percent encoded. Attempting to set an incorrectly percent encoded string will cause a `fatalError`. Although ';' is a legal path character, it is recommended that it be percent-encoded for best compatibility with `URL` (`String.addingPercentEncoding(withAllowedCharacters:)` will percent-encode any ';' characters if you pass `CharacterSet.urlHostAllowed`).
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use encodedHost instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use encodedHost instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use encodedHost instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use encodedHost instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use encodedHost instead")
    public var percentEncodedHost: String? {
        get { components.percentEncodedHost }
        set {
            do {
                try components.setPercentEncodedHost(newValue)
            } catch {
                fatalError("Attempting to set percentEncodedHost with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPercentEncodedHost(_ newValue: String?) throws {
        try components.setPercentEncodedHost(newValue)
    }
#endif

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public var encodedHost: String? {
        get { components.encodedHost }
        set {
            do {
                try components.setEncodedHost(newValue)
            } catch {
                fatalError("Attempting to set encodedHost with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setEncodedHost(_ newValue: String?) throws {
        try components.setEncodedHost(newValue)
    }
#endif

    /// The path subcomponent, percent-encoded.
    ///
    /// The getter for this property retains any percent encoding this component may have. Setting this properties assumes the component string is already correctly percent encoded. Attempting to set an incorrectly percent encoded string will cause a `fatalError`. Although ';' is a legal path character, it is recommended that it be percent-encoded for best compatibility with `URL` (`String.addingPercentEncoding(withAllowedCharacters:)` will percent-encode any ';' characters if you pass `CharacterSet.urlPathAllowed`).
    public var percentEncodedPath: String {
        get { components.percentEncodedPath }
        set {
            do {
                try components.setPercentEncodedPath(newValue)
            } catch {
                fatalError("Attempting to set percentEncodedPath with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPercentEncodedPath(_ newValue: String) throws {
        try components.setPercentEncodedPath(newValue)
    }
#endif

    /// The query subcomponent, percent-encoded.
    ///
    /// The getter for this property retains any percent encoding this component may have. Setting this properties assumes the component string is already correctly percent encoded. Attempting to set an incorrectly percent encoded string will cause a `fatalError`. Although ';' is a legal path character, it is recommended that it be percent-encoded for best compatibility with `URL` (`String.addingPercentEncoding(withAllowedCharacters:)` will percent-encode any ';' characters if you pass `CharacterSet.urlQueryAllowed`).
    public var percentEncodedQuery: String? {
        get { components.percentEncodedQuery }
        set {
            do {
                try components.setPercentEncodedQuery(newValue)
            } catch {
                fatalError("Attempting to set percentEncodedQuery with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPercentEncodedQuery(_ newValue: String?) throws {
        try components.setPercentEncodedQuery(newValue)
    }
#endif

    /// The fragment subcomponent, percent-encoded.
    ///
    /// The getter for this property retains any percent encoding this component may have. Setting this properties assumes the component string is already correctly percent encoded. Attempting to set an incorrectly percent encoded string will cause a `fatalError`. Although ';' is a legal path character, it is recommended that it be percent-encoded for best compatibility with `URL` (`String.addingPercentEncoding(withAllowedCharacters:)` will percent-encode any ';' characters if you pass `CharacterSet.urlFragmentAllowed`).
    public var percentEncodedFragment: String? {
        get { components.percentEncodedFragment }
        set {
            do {
                try components.setPercentEncodedFragment(newValue)
            } catch {
                fatalError("Attempting to set percentEncodedFragment with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPercentEncodedFragment(_ newValue: String?) throws {
        try components.setPercentEncodedFragment(newValue)
    }
#endif

    /// Returns the character range of the scheme in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfScheme: Range<String.Index>? {
        components.rangeOf(.scheme)
    }

    /// Returns the character range of the user in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfUser: Range<String.Index>? {
        components.rangeOf(.user)
    }

    /// Returns the character range of the password in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfPassword: Range<String.Index>? {
        components.rangeOf(.password)
    }

    /// Returns the character range of the host in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfHost: Range<String.Index>? {
        components.rangeOf(.host)
    }

    /// Returns the character range of the port in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfPort: Range<String.Index>? {
        components.rangeOf(.port)
    }

    /// Returns the character range of the path in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfPath: Range<String.Index>? {
        components.rangeOf(.path)
    }

    /// Returns the character range of the query in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfQuery: Range<String.Index>? {
        components.rangeOf(.query)
    }

    /// Returns the character range of the fragment in the string returned by `var string`.
    ///
    /// If the component does not exist, nil is returned.
    /// - note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var rangeOfFragment: Range<String.Index>? {
        components.rangeOf(.fragment)
    }

    /// Returns an array of query items for this `URLComponents`, in the order in which they appear in the original query string.
    ///
    /// Each `URLQueryItem` represents a single key-value pair,
    ///
    /// Note that a name may appear more than once in a single query string, so the name values are not guaranteed to be unique. If the `URLComponents` has an empty query component, returns an empty array. If the `URLComponents` has no query component, returns nil.
    ///
    /// The setter combines an array containing any number of `URLQueryItem`s, each of which represents a single key-value pair, into a query string and sets the `URLComponents` query property. Passing an empty array sets the query component of the `URLComponents` to an empty string. Passing nil removes the query component of the `URLComponents`.
    ///
    /// - note: If a name-value pair in a query is empty (i.e. the query string starts with '&', ends with '&', or has "&&" within it), you get a `URLQueryItem` with a zero-length name and a nil value. If a query's name-value pair has nothing before the equals sign, you get a zero-length name. If a query's name-value pair has nothing after the equals sign, you get a zero-length value. If a query's name-value pair has no equals sign, the query name-value pair string is the name and you get a nil value.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var queryItems: [URLQueryItem]? {
        get { components.queryItems(percentEncoded: false) }
        set { components.setQueryItems(newValue) }
    }

    /// Returns an array of query items for this `URLComponents`, in the order in which they appear in the original query string. Any percent-encoding in a query item name or value is retained
    ///
    /// The setter combines an array containing any number of `URLQueryItem`s, each of which represents a single key-value pair, into a query string and sets the `URLComponents` query property. This property assumes the query item names and values are already correctly percent-encoded, and that the query item names do not contain the query item delimiter characters '&' and '='. Attempting to set an incorrectly percent-encoded query item or a query item name with the query item delimiter characters '&' and '=' will cause a `fatalError`.
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public var percentEncodedQueryItems: [URLQueryItem]? {
        get { components.queryItems(percentEncoded: true) }
        set {
            do {
                try components.setPercentEncodedQueryItems(newValue)
            } catch {
                fatalError("Attempting to set percentEncodedQueryItems with invalid characters")
            }
        }
    }

#if FOUNDATION_FRAMEWORK
    /// Throwing function used by `_NSSwiftURLComponents` to generate an exception for ObjC callers
    internal mutating func setPercentEncodedQueryItems(_ newValue: [URLQueryItem]?) throws {
        try components.setPercentEncodedQueryItems(newValue)
    }
#endif

    public func hash(into hasher: inout Hasher) {
        hasher.combine(scheme)
        hasher.combine(percentEncodedUser)
        hasher.combine(percentEncodedPassword)
        hasher.combine(encodedHost)
        hasher.combine(port)
        hasher.combine(percentEncodedPath)
        hasher.combine(percentEncodedQuery)
        hasher.combine(percentEncodedFragment)
    }

    // MARK: - Bridging

    public static func ==(lhs: URLComponents, rhs: URLComponents) -> Bool {
        return (
            // Check in (estimated) order of most likely to exist, so we fail faster if non-equal.
            lhs.percentEncodedPath == rhs.percentEncodedPath &&
            lhs.scheme == rhs.scheme &&
            lhs.encodedHost == rhs.encodedHost &&
            lhs.port == rhs.port &&
            lhs.percentEncodedQuery == rhs.percentEncodedQuery &&
            lhs.percentEncodedFragment == rhs.percentEncodedFragment &&
            lhs.percentEncodedUser == rhs.percentEncodedUser &&
            lhs.percentEncodedPassword == rhs.percentEncodedPassword
        )
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URLComponents: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {

    public var description: String {
        if let u = url {
            return u.description
        } else {
            return self.customMirror.children.reduce(into: "") {
                $0 += "\($1.label ?? ""): \($1.value) "
            }
        }
    }

    public var debugDescription: String {
        return self.description
    }

    public var customMirror: Mirror {
        var c: [(label: String?, value: Any)] = []

        if let s = self.scheme { c.append((label: "scheme", value: s)) }
        if let u = self.user { c.append((label: "user", value: u)) }
        if let pw = self.password { c.append((label: "password", value: pw)) }
        if let h = self.host { c.append((label: "host", value: h)) }
        if let p = self.port { c.append((label: "port", value: p)) }

        c.append((label: "path", value: self.path))
        if let qi = self.queryItems { c.append((label: "queryItems", value: qi)) }
        if let f = self.fragment { c.append((label: "fragment", value: f)) }
        let m = Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
        return m
    }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URLComponents: ReferenceConvertible, _ObjectiveCBridgeable {

    public typealias ReferenceType = NSURLComponents

    public static func _getObjectiveCType() -> Any.Type {
        return NSURLComponents.self
    }

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSURLComponents {
        _NSSwiftURLComponents(components: self)
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSURLComponents, result: inout URLComponents?) {
        if !_conditionallyBridgeFromObjectiveC(x, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSURLComponents, result: inout URLComponents?) -> Bool {
        var comp = URLComponents()
        comp.scheme = x.scheme
        comp.user = x.user
        comp.password = x.password
        comp.host = x.host
        comp.port = x.port?.intValue
        comp.path = x.path ?? ""
        comp.query = x.query
        comp.fragment = x.fragment
        result = comp
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSURLComponents?) -> URLComponents {
        guard let src = source else { return URLComponents() }
        var result: URLComponents? = URLComponents()
        _ = _conditionallyBridgeFromObjectiveC(src, result: &result)
        return result!
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSURLComponents: _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as URLComponents)
    }
}
#endif // FOUNDATION_FRAMEWORK


/// A single name-value pair, for use with `URLComponents`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct URLQueryItem: Hashable, Equatable, Sendable {

    public var name: String
    public var value: String?

    public init(name: __shared String, value: __shared String?) {
        self.name = name
        self.value = value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(value)
    }

    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public static func ==(lhs: URLQueryItem, rhs: URLQueryItem) -> Bool {
        return lhs.name == rhs.name && lhs.value == rhs.value
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URLQueryItem: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {

    public var description: String {
        if let v = value {
            return "\(name)=\(v)"
        } else {
            return name
        }
    }

    public var debugDescription: String {
        return self.description
    }

    public var customMirror: Mirror {
        let c: [(label: String?, value: Any)] = [
            ("name", name),
            ("value", value as Any),
        ]
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URLQueryItem: ReferenceConvertible, _ObjectiveCBridgeable {

    public typealias ReferenceType = NSURLQueryItem

    public static func _getObjectiveCType() -> Any.Type {
        return NSURLQueryItem.self
    }

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSURLQueryItem {
        return _NSSwiftURLQueryItem(queryItem: self)
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSURLQueryItem, result: inout URLQueryItem?) {
        if !_conditionallyBridgeFromObjectiveC(x, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSURLQueryItem, result: inout URLQueryItem?) -> Bool {
        result = URLQueryItem(name: x.name, value: x.value)
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSURLQueryItem?) -> URLQueryItem {
        var result: URLQueryItem?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSURLQueryItem: _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as URLQueryItem)
    }
}
#endif // FOUNDATION_FRAMEWORK

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URLComponents: Codable {
    private enum CodingKeys: Int, CodingKey {
        case scheme
        case user
        case password
        case host
        case port
        case path
        case query
        case fragment
    }

    public init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scheme = try container.decodeIfPresent(String.self, forKey: .scheme)
        self.user = try container.decodeIfPresent(String.self, forKey: .user)
        self.password = try container.decodeIfPresent(String.self, forKey: .password)
        self.host = try container.decodeIfPresent(String.self, forKey: .host)
        self.port = try container.decodeIfPresent(Int.self, forKey: .port)
        self.path = try container.decode(String.self, forKey: .path)
        self.query = try container.decodeIfPresent(String.self, forKey: .query)
        self.fragment = try container.decodeIfPresent(String.self, forKey: .fragment)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.scheme, forKey: .scheme)
        try container.encodeIfPresent(self.user, forKey: .user)
        try container.encodeIfPresent(self.password, forKey: .password)
        try container.encodeIfPresent(self.host, forKey: .host)
        try container.encodeIfPresent(self.port, forKey: .port)
        try container.encode(self.path, forKey: .path)
        try container.encodeIfPresent(self.query, forKey: .query)
        try container.encodeIfPresent(self.fragment, forKey: .fragment)
    }
}
