//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif os(Windows)
import WinSDK
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

#if canImport(os)
internal import os
#endif

/// `_SwiftURL` provides the new Swift implementation for `URL`, using the same parser
/// and `URLParseInfo` as `URLComponents`, but with a few compatibility behaviors.
///
/// Outside of `FOUNDATION_FRAMEWORK`, `_SwiftURL` provides the sole implementation
/// for `URL`. In `FOUNDATION_FRAMEWORK`, there are additional classes to handle `NSURL`
/// subclassing and bridging from ObjC.
///
/// - Note: For functions returning `URL?`, a `nil` return value allows `struct URL` to return `self` without creating a new struct.
internal final class _SwiftURL: Sendable, Hashable, Equatable {
    typealias Parser = RFC3986Parser
    internal let _parseInfo: URLParseInfo
    internal let _baseURL: URL?
    internal let _encoding: String.Encoding
    // URL was created from a file path initializer and is absolute
    private let _isCanonicalFileURL: Bool

    #if FOUNDATION_FRAMEWORK
    // Used frequently for NS/CFURL behaviors
    internal var isDecomposable: Bool {
        return _parseInfo.scheme == nil || hasAuthority || _parseInfo.path.utf8.first == ._slash
    }

    // For use by CoreServicesInternal to cache property values.
    internal final class ResourceInfo: @unchecked Sendable {
        let ref = LockedState<CFTypeRef?>(initialState: nil)
    }
    internal let _resourceInfo = ResourceInfo()

    // Only used if foundation_swift_nsurl_enabled() is false.
    // Note: We use a lock instead of a lazy var to ensure that we always
    // bridge to the same NSURL even if the URL was copied across threads.
    private let _nsurlLock = LockedState<NSURL?>(initialState: nil)
    private var _nsurl: NSURL {
        return _nsurlLock.withLock {
            if let nsurl = $0 { return nsurl }
            let nsurl = Self._makeNSURL(from: _parseInfo, baseURL: _baseURL)
            $0 = nsurl
            return nsurl
        }
    }
    #endif

    internal var url: URL {
        URL(self)
    }

    private static func parse(string: String, encodingInvalidCharacters: Bool = true) -> URLParseInfo? {
        return Parser.parse(urlString: string, encodingInvalidCharacters: encodingInvalidCharacters, allowEmptyScheme: true)
    }

    private static func compatibilityParse(string: String, encodingInvalidCharacters: Bool = false) -> URLParseInfo? {
        return Parser.compatibilityParse(urlString: string, encodingInvalidCharacters: encodingInvalidCharacters)
    }

    init?(stringOrEmpty: String, relativeTo base: URL? = nil, encodingInvalidCharacters: Bool = true, encoding: String.Encoding = .utf8, compatibility: Bool = false, forceBaseURL: Bool = false) {
        let parseInfo = if compatibility {
            Self.compatibilityParse(string: stringOrEmpty, encodingInvalidCharacters: encodingInvalidCharacters)
        } else {
            Self.parse(string: stringOrEmpty, encodingInvalidCharacters: encodingInvalidCharacters)
        }
        guard let parseInfo else { return nil }
        _parseInfo = parseInfo
        _baseURL = (forceBaseURL || parseInfo.scheme == nil) ? base?.absoluteURL : nil
        _encoding = encoding
        _isCanonicalFileURL = false
    }

    convenience init?(string: String) {
        guard !string.isEmpty else { return nil }
        self.init(stringOrEmpty: string)
    }
    
    convenience init?(string: String, relativeTo base: URL?) {
        guard !string.isEmpty else { return nil }
        self.init(stringOrEmpty: string, relativeTo: base)
    }
    
    convenience init?(string: String, encodingInvalidCharacters: Bool) {
        guard !string.isEmpty else { return nil }
        self.init(stringOrEmpty: string, encodingInvalidCharacters: encodingInvalidCharacters)
    }

    convenience init?(stringOrEmpty: String, relativeTo base: URL?) {
        self.init(stringOrEmpty: stringOrEmpty, relativeTo: base, encoding: .utf8)
    }

    convenience init(fileURLWithPath path: String, isDirectory: Bool, relativeTo base: URL?) {
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint, relativeTo: base)
    }
    
    convenience init(fileURLWithPath path: String, relativeTo base: URL?) {
        let directoryHint: URL.DirectoryHint = path.utf8.last == ._slash ? .isDirectory : .checkFileSystem
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint, relativeTo: base)
    }
    
    convenience init(fileURLWithPath path: String, isDirectory: Bool) {
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint)
    }
    
    convenience init(fileURLWithPath path: String) {
        let directoryHint: URL.DirectoryHint = path.utf8.last == ._slash ? .isDirectory : .checkFileSystem
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint)
    }

    convenience init(filePath path: String, directoryHint: URL.DirectoryHint = .inferFromPath, relativeTo base: URL? = nil) {
        // .init(fileURLWithPath:) inits call through here, convert path to FSR now
        self.init(filePath: path.fileSystemRepresentation, pathStyle: URL.defaultPathStyle, directoryHint: directoryHint, relativeTo: base)
    }

    internal init(filePath path: String, pathStyle: URL.PathStyle, directoryHint: URL.DirectoryHint = .inferFromPath, relativeTo base: URL? = nil) {
        // Note: don't convert to file system representation in this init since
        // .init(fileURLWithFileSystemRepresentation:) calls into it, too.
        var baseURL = base
        guard !path.isEmpty else {
            #if !NO_FILESYSTEM
            baseURL = baseURL ?? Self.currentDirectoryOrNil()
            #endif
            _parseInfo = Parser.parse(filePath: "./", isAbsolute: false)
            _baseURL = baseURL?.absoluteURL
            _encoding = .utf8
            _isCanonicalFileURL = false
            return
        }

        var filePath = if pathStyle == .windows {
            // Convert any "\" to "/" before storing the URL parse info
            path.replacing(._backslash, with: ._slash)
        } else {
            path
        }

        #if FOUNDATION_FRAMEWORK
        // Linked-on-or-after check for apps which incorrectly pass a full URL
        // string with a scheme. In the old implementation, this could work
        // rarely if the app immediately called .appendingPathComponent(_:),
        // which used to accidentally interpret a relative path starting with
        // "scheme:" as an absolute "scheme:" URL string.
        if URL.compatibility1 {
            if filePath.utf8.starts(with: "file:".utf8) {
                #if canImport(os)
                URL.logger.fault("API MISUSE: URL(filePath:) called with a \"file:\" scheme. Input must only contain a path. Dropping \"file:\" scheme.")
                #endif
                filePath = String(filePath.dropFirst(5))._compressingSlashes()
            } else if filePath.utf8.starts(with: "http:".utf8) || filePath.utf8.starts(with: "https:".utf8) {
                #if canImport(os)
                URL.logger.fault("API MISUSE: URL(filePath:) called with an HTTP URL string. Using URL(string:) instead.")
                #endif
                guard let parseInfo = Self.parse(string: filePath, encodingInvalidCharacters: true) else {
                    fatalError("API MISUSE: URL(filePath:) called with an HTTP URL string. URL(string:) returned nil.")
                }
                _parseInfo = parseInfo
                _baseURL = nil // Drop the base URL since we have an HTTP scheme
                _encoding = .utf8
                _isCanonicalFileURL = false
                return
            }
        }
        #endif

        let isAbsolute = URL.isAbsolute(standardizing: &filePath, pathStyle: pathStyle)

        #if !NO_FILESYSTEM
        if !isAbsolute {
            baseURL = baseURL ?? Self.currentDirectoryOrNil()
        }
        #endif

        let isDirectory: Bool
        switch directoryHint {
        case .isDirectory:
            isDirectory = true
        case .notDirectory:
            filePath = filePath._droppingTrailingSlashes
            isDirectory = false
        case .checkFileSystem:
            #if !NO_FILESYSTEM
            func absoluteFilePath() -> String {
                guard !isAbsolute, let baseURL else {
                    return filePath
                }
                let absolutePath = baseURL.absolutePath(percentEncoded: true).merging(relativePath: filePath)
                return Self.fileSystemPath(for: absolutePath)
            }
            isDirectory = Self.isDirectory(absoluteFilePath())
            #else
            isDirectory = filePath.utf8.last == ._slash
            #endif
        case .inferFromPath:
            isDirectory = filePath.utf8.last == ._slash
        }

        if isDirectory && !filePath.isEmpty && filePath.utf8.last != ._slash {
            filePath += "/"
        }
        if isAbsolute {
            let encodedPath = Parser.percentEncode(filePath, component: .path) ?? "/"
            _parseInfo = Parser.parse(filePath: encodedPath, isAbsolute: true)
            _baseURL = nil // Drop the baseURL if the URL is absolute
            _isCanonicalFileURL = true
        } else {
            let encodedPath = Parser.percentEncode(filePath, component: .path) ?? ""
            _parseInfo = Parser.parse(filePath: encodedPath, isAbsolute: false)
            _baseURL = baseURL?.absoluteURL
            _isCanonicalFileURL = false
        }
        _encoding = .utf8
    }

    init(url: _SwiftURL) {
        _parseInfo = url._parseInfo
        _baseURL = url._baseURL?.absoluteURL
        _encoding = url._encoding
        _isCanonicalFileURL = url._isCanonicalFileURL
    }

    convenience init?(dataRepresentation: Data, relativeTo base: URL?, isAbsolute: Bool) {
        guard !dataRepresentation.isEmpty else { return nil }
        var url: _SwiftURL?
        if let string = String(data: dataRepresentation, encoding: .utf8) {
            url = _SwiftURL(stringOrEmpty: string, relativeTo: base, encoding: .utf8, compatibility: true)
        }
        if url == nil, let string = String(data: dataRepresentation, encoding: .isoLatin1) {
            url = _SwiftURL(stringOrEmpty: string, relativeTo: base, encoding: .isoLatin1, compatibility: true)
        }
        guard let url else {
            return nil
        }
        if isAbsolute {
            self.init(url: url.absoluteSwiftURL)
        } else {
            self.init(url: url)
        }
    }
    
    convenience init(fileURLWithFileSystemRepresentation path: UnsafePointer<Int8>, isDirectory: Bool, relativeTo base: URL?) {
        let pathString = String(cString: path)
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        // Call the internal init so we don't automatically convert path to its decomposed form
        self.init(filePath: pathString, pathStyle: URL.defaultPathStyle, directoryHint: directoryHint, relativeTo: base)
    }

    internal var encodedComponents: URLParseInfo.EncodedComponentSet {
        return _parseInfo.encodedComponents
    }

    // MARK: - Strings, Data, and URLs

    internal var originalString: String {
        guard !encodedComponents.isEmpty else {
            return relativeString
        }
        return URLComponents(parseInfo: _parseInfo)._uncheckedString(original: true)
    }

    var dataRepresentation: Data {
        guard let result = originalString.data(using: _encoding) else {
            fatalError("Could not convert URL.relativeString to data using encoding: \(_encoding)")
        }
        return result
    }

    var relativeString: String {
        return _parseInfo.urlString
    }

    internal func absoluteString(original: Bool) -> String {
        guard let baseURL else {
            return original ? originalString : relativeString
        }
        var builder = URLStringBuilder(parseInfo: _parseInfo, original: original)
        if builder.scheme != nil {
            builder.path = builder.path.removingDotSegments
            return builder.string
        }
        if let baseScheme = baseURL.scheme {
            builder.scheme = baseScheme
        }
        if hasAuthority {
            return builder.string
        }
        let baseParseInfo = baseURL._swiftURL?._parseInfo
        // If we aren't in the special case where we need the original
        // string, always leave the base components encoded.
        let baseComponentsToDecode = !original ? [] : baseParseInfo?.encodedComponents ?? []
        if let baseUser = baseURL.user(percentEncoded: !baseComponentsToDecode.contains(.user)) {
            builder.user = baseUser
        }
        if let basePassword = baseURL.password(percentEncoded: !baseComponentsToDecode.contains(.password)) {
            builder.password = basePassword
        }
        if let baseHost = baseParseInfo?.host {
            builder.host = baseComponentsToDecode.contains(.host) && baseParseInfo!.didPercentEncodeHost ? Parser.percentDecode(baseHost) : String(baseHost)
        } else if let baseHost = baseURL.host(percentEncoded: !baseComponentsToDecode.contains(.host)) {
            builder.host = baseHost
        }
        if let basePort = baseParseInfo?.portString {
            builder.portString = String(basePort)
        } else if let basePort = baseURL.port {
            builder.portString = String(basePort)
        }
        if builder.path.isEmpty {
            builder.path = baseURL.path(percentEncoded: !baseComponentsToDecode.contains(.path))
            if builder.query == nil, let baseQuery = baseURL.query(percentEncoded: !baseComponentsToDecode.contains(.query)) {
                builder.query = baseQuery
            }
        } else {
            let newPath = if builder.path.utf8.first == ._slash {
                builder.path
            } else if baseURL.hasAuthority && baseURL.path().isEmpty {
                "/" + builder.path
            } else {
                baseURL.path(percentEncoded: !baseComponentsToDecode.contains(.path)).merging(relativePath: builder.path)
            }
            builder.path = newPath.removingDotSegments
        }
        return builder.string
    }

    var absoluteString: String {
        return absoluteString(original: false)
    }

    var baseURL: URL? {
        return _baseURL
    }

    private var absoluteSwiftURL: _SwiftURL {
        guard baseURL != nil else { return self }
        return _SwiftURL(stringOrEmpty: absoluteString(original: false), encoding: _encoding, compatibility: true) ?? self
    }

    var absoluteURL: URL? {
        guard baseURL != nil else { return nil }
        return absoluteSwiftURL.url
    }

    // Compatibility mode for CFURLCreateAbsoluteURLWithBytes
    internal var compatibilityAbsoluteString: String {
        guard let baseURL = baseURL?._swiftURL else {
            return URLStringBuilder(parseInfo: _parseInfo, original: true).removingDotSegments.string
        }
        let first = originalString.utf8.first
        if first == nil || first == UInt8(ascii: "?") || first == UInt8(ascii: "#") {
            return URLStringBuilder(parseInfo: baseURL._parseInfo, original: true).removingDotSegments.string + originalString
        }
        var builder = URLStringBuilder(parseInfo: _parseInfo, original: true)
        if let scheme {
            guard scheme == baseURL.scheme else {
                return URLStringBuilder(parseInfo: _parseInfo, original: true).removingDotSegments.string
            }
            builder.scheme = nil
        }
        guard let newURL = _SwiftURL(stringOrEmpty: builder.string, relativeTo: _baseURL, encodingInvalidCharacters: true, encoding: _encoding, compatibility: true) else {
            return absoluteString(original: true)
        }
        return newURL.absoluteString(original: true)
    }

    internal var compatibilityAbsoluteURL: URL? {
        return _SwiftURL(stringOrEmpty: compatibilityAbsoluteString, encodingInvalidCharacters: true, encoding: _encoding, compatibility: true)?.url
    }

    // MARK: - Components

    var scheme: String? {
        guard let scheme = _parseInfo.scheme else { return baseURL?.scheme }
        return String(scheme)
    }

    private static let fileSchemeUTF8 = Array("file".utf8)
    var isFileURL: Bool {
        if _isCanonicalFileURL { return true }
        guard let scheme else { return false }
        return scheme.lowercased().utf8.elementsEqual(Self.fileSchemeUTF8)
    }

    var hasAuthority: Bool {
        return _parseInfo.hasAuthority
    }

    internal var netLocation: String? {
        guard hasAuthority else {
            return baseURL?._swiftURL?.netLocation
        }
        guard let netLocation = _parseInfo.netLocation else {
            return nil
        }
        return String(netLocation)
    }

    var user: String? {
        return user(percentEncoded: false)
    }

    func user(percentEncoded: Bool) -> String? {
        if !hasAuthority { return baseURL?.user(percentEncoded: percentEncoded) }
        guard let user = _parseInfo.user else { return nil }
        if percentEncoded {
            return String(user)
        } else if encodedComponents.contains(.user) {
            // If we encoded it using UTF-8, decode it using UTF-8
            return Parser.percentDecode(user)
        } else {
            // Otherwise, use the encoding we were given
            return Parser.percentDecode(user, encoding: _encoding)
        }
    }
    
    var password: String? {
        return password(percentEncoded: true)
    }

    func password(percentEncoded: Bool) -> String? {
        if !hasAuthority { return baseURL?.password(percentEncoded: percentEncoded) }
        guard let password = _parseInfo.password else { return nil }
        if percentEncoded {
            return String(password)
        } else if encodedComponents.contains(.password) {
            return Parser.percentDecode(password)
        } else {
            return Parser.percentDecode(password, encoding: _encoding)
        }
    }

    var host: String? {
        return host(percentEncoded: false)
    }

    func host(percentEncoded: Bool) -> String? {
        if !hasAuthority { return baseURL?.host(percentEncoded: percentEncoded) }
        guard let encodedHost = _parseInfo.host.map(String.init) else { return nil }

        // According to RFC 3986, a host always exists if there is an authority
        // component, it just might be empty. However, the old implementation
        // of URL.host() returned nil for URLs like "https:///", and apps rely
        // on this behavior, so keep it for bincompat.
        if encodedHost.isEmpty && _parseInfo.user == nil && _parseInfo.password == nil && _parseInfo.portRange == nil {
            return nil
        }

        func requestedHost() -> String? {
            if percentEncoded {
                if !encodedComponents.contains(.host) || _parseInfo.didPercentEncodeHost {
                    return encodedHost
                }
                // Now we need to IDNA-decode, then percent-encode
                guard let decoded = Parser.IDNADecodeHost(encodedHost) else {
                    return encodedHost
                }
                return Parser.percentEncode(decoded, component: .host)
            } else if encodedComponents.contains(.host) {
                if _parseInfo.didPercentEncodeHost {
                    return Parser.percentDecode(encodedHost)
                }
                // Return IDNA-encoded host, which is technically not percent-encoded
                return encodedHost
            } else {
                return Parser.percentDecode(encodedHost, encoding: _encoding)
            }
        }

        guard let requestedHost = requestedHost() else {
            return nil
        }

        if _parseInfo.isIPLiteral {
            // Strip square brackets to be compatible with old URL.host behavior
            return String(requestedHost.utf8.dropFirst().dropLast())
        } else {
            return requestedHost
        }
    }

    var port: Int? {
        return hasAuthority ? _parseInfo.port : baseURL?.port
    }

    var relativePath: String {
        return Self.fileSystemPath(for: relativePath(percentEncoded: true))
    }

    func relativePath(percentEncoded: Bool) -> String {
        if percentEncoded {
            return String(_parseInfo.path)
        } else if encodedComponents.contains(.path) {
            return Parser.percentDecode(_parseInfo.path) ?? ""
        } else {
            return Parser.percentDecode(_parseInfo.path, encoding: _encoding) ?? ""
        }
    }

    func absolutePath(percentEncoded: Bool) -> String {
        if baseURL != nil {
            return absoluteURL?.relativePath(percentEncoded: percentEncoded) ?? relativePath(percentEncoded: percentEncoded)
        }
        if percentEncoded {
            return String(_parseInfo.path)
        } else if encodedComponents.contains(.path) {
            return Parser.percentDecode(_parseInfo.path) ?? ""
        } else {
            return Parser.percentDecode(_parseInfo.path, encoding: _encoding) ?? ""
        }
    }

    var path: String {
        if isFileURL { return fileSystemPath() }
        let path = absolutePath(percentEncoded: true)
        if encodedComponents.contains(.path) {
            return Parser.percentDecode(path)?._droppingTrailingSlashes ?? ""
        } else {
            return Parser.percentDecode(path, encoding: _encoding)?._droppingTrailingSlashes ?? ""
        }
    }

    func path(percentEncoded: Bool) -> String {
        return absolutePath(percentEncoded: percentEncoded)
    }
    
    var query: String? {
        return query(percentEncoded: true)
    }

    func query(percentEncoded: Bool) -> String? {
        let query = _parseInfo.query
        if query == nil && !hasAuthority && _parseInfo.path.isEmpty {
            return baseURL?.query(percentEncoded: percentEncoded)
        }
        guard let query else { return nil }
        if percentEncoded {
            return String(query)
        } else if encodedComponents.contains(.query) {
            return Parser.percentDecode(query)
        } else {
            return Parser.percentDecode(query, encoding: _encoding)
        }
    }
    
    var fragment: String? {
        return fragment(percentEncoded: true)
    }

    func fragment(percentEncoded: Bool) -> String? {
        guard let fragment = _parseInfo.fragment else { return nil }
        if percentEncoded {
            return String(fragment)
        } else if encodedComponents.contains(.fragment) {
            return Parser.percentDecode(fragment)
        } else {
            return Parser.percentDecode(fragment, encoding: _encoding)
        }
    }

    // MARK: - File Paths

    private static func decodeFilePath(_ path: some StringProtocol) -> String {
        // Don't decode "%2F" or "%00"
        let charsToLeaveEncoded: Set<UInt8> = [._slash, 0]
        return Parser.percentDecode(path, excluding: charsToLeaveEncoded) ?? ""
    }

    private static func windowsPath(for urlPath: String, slashDropper: (String) -> String) -> String {
        var iter = urlPath.utf8.makeIterator()
        guard iter.next() == ._slash else {
            return decodeFilePath(slashDropper(urlPath))
        }
        // "C:\" is standardized to "/C:/" on initialization.
        if let driveLetter = iter.next(), driveLetter.isAlpha,
           iter.next() == ._colon,
           iter.next() == ._slash {
            // Strip trailing slashes from the path, which preserves a root "/".
            let path = slashDropper(String(Substring(urlPath.utf8.dropFirst(3))))
            // Don't include a leading slash before the drive letter
            return "\(Unicode.Scalar(driveLetter)):\(decodeFilePath(path))"
        }
        // There are many flavors of UNC paths, so use PathIsRootW to ensure
        // we don't strip a trailing slash that represents a root.
        let path = decodeFilePath(urlPath)
        #if os(Windows)
        return path.replacing(._slash, with: ._backslash).withCString(encodedAs: UTF16.self) { pwszPath in
            guard !PathIsRootW(pwszPath) else {
                return path
            }
            return slashDropper(path)
        }
        #else
        return slashDropper(path)
        #endif
    }

    internal static func fileSystemPath(for urlPath: String, style: URL.PathStyle = URL.defaultPathStyle, compatibility: Bool = false) -> String {
        let slashDropper: (String) -> String = if compatibility {
            { $0._droppingTrailingSlash }
        } else {
            { $0._droppingTrailingSlashes }
        }
        switch style {
        case .posix: return decodeFilePath(slashDropper(urlPath))
        case .windows: return windowsPath(for: urlPath, slashDropper: slashDropper)
        }
    }

    internal func fileSystemPath(style: URL.PathStyle = URL.defaultPathStyle, resolveAgainstBase: Bool = true, compatibility: Bool = false) -> String {
        let urlPath = resolveAgainstBase ? absolutePath(percentEncoded: true) : relativePath(percentEncoded: true)
        return Self.fileSystemPath(for: urlPath, style: style, compatibility: compatibility)
    }

    func withUnsafeFileSystemRepresentation<ResultType>(_ block: (UnsafePointer<Int8>?) throws -> ResultType) rethrows -> ResultType {
        #if !os(Windows)
        if _isCanonicalFileURL {
            return try fileSystemPath().withCString { try block($0) }
        }
        #endif
        return try fileSystemPath().withFileSystemRepresentation { try block($0) }
    }
    
    var hasDirectoryPath: Bool {
        let path = String(_parseInfo.path)
        if path.utf8.last == ._slash {
            return true
        }
        if path.isEmpty {
            return _parseInfo.scheme == nil && !hasAuthority && baseURL?.hasDirectoryPath == true
        }
        return path.lastPathComponent == "." || path.lastPathComponent == ".."
    }

    var pathComponents: [String] {
        var result = absolutePath(percentEncoded: true).pathComponents.map { Parser.percentDecode($0) ?? "" }
        if result.count > 1 && result.last == "/" {
            _ = result.popLast()
        }
        return result
    }

    var lastPathComponent: String {
        let component = absolutePath(percentEncoded: true).lastPathComponent
        if isFileURL {
            return Self.fileSystemPath(for: component)
        } else {
            return Parser.percentDecode(component, encoding: _encoding) ?? ""
        }
    }

    var pathExtension: String {
        return path.pathExtension
    }

    func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL? {
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        return appending(path: pathComponent, directoryHint: directoryHint)
    }
    
    func appendingPathComponent(_ pathComponent: String) -> URL? {
        return appending(path: pathComponent, directoryHint: .checkFileSystem)
    }

    func appending<S>(path: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        return appending(path: path, directoryHint: directoryHint, encodingSlashes: false)
    }

    func appending<S>(component: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        // The old .appending(component:) implementation did not actually percent-encode
        // "/" for file URLs as the documentation suggests. Many apps accidentally use
        // .appending(component: "path/with/slashes") instead of using .appending(path:),
        // so changing this behavior would cause breakage.
        if isFileURL {
            return appending(path: component, directoryHint: directoryHint, encodingSlashes: false)
        }
        return appending(path: component, directoryHint: directoryHint, encodingSlashes: true)
    }

    internal func appending<S: StringProtocol>(path: S, directoryHint: URL.DirectoryHint, encodingSlashes: Bool, compatibility: Bool = false) -> URL? {
        guard !path.isEmpty || !_parseInfo.path.isEmpty || _parseInfo.netLocationRange?.isEmpty == false else {
            return nil
        }
        #if os(Windows)
        var pathToAppend = path.replacing(._backslash, with: ._slash)
        #else
        var pathToAppend = String(path)
        #endif

        #if FOUNDATION_FRAMEWORK
        if isFileURL {
            // Use the file system (decomposed) representation
            pathToAppend = pathToAppend.fileSystemRepresentation
        }
        #endif

        if !encodingSlashes && !compatibility {
            pathToAppend = Parser.percentEncode(pathComponent: pathToAppend)
        } else {
            var toEncode = Set<UInt8>()
            if encodingSlashes {
                toEncode.insert(._slash)
            }
            if compatibility {
                toEncode.insert(._semicolon)
            }
            pathToAppend = Parser.percentEncode(pathComponent: pathToAppend, including: toEncode)
        }

        func appendedPath() -> String {
            var currentPath = relativePath(percentEncoded: true)
            if currentPath.isEmpty && !hasAuthority {
                guard _parseInfo.scheme == nil else {
                    // Scheme only, append directly to the empty path, e.g.
                    // URL("scheme:").appending(path: "path") == scheme:path
                    return pathToAppend
                }
                // No scheme or authority, treat the empty path as "."
                currentPath = "."
            }

            // If currentPath is empty, pathToAppend is relative, and we have an authority,
            // we must append a slash to separate the path from authority, which happens below.

            if currentPath.utf8.last != ._slash && pathToAppend.utf8.first != ._slash {
                currentPath += "/"
            } else if currentPath.utf8.last == ._slash && pathToAppend.utf8.first == ._slash {
                _ = currentPath.popLast()
            }
            return currentPath + pathToAppend
        }

        func mergedPath(for relativePath: String) -> String {
            precondition(relativePath.utf8.first != UInt8(ascii: "/"))
            guard let baseURL else {
                return relativePath
            }
            let basePath = baseURL.relativePath(percentEncoded: true)
            if baseURL.hasAuthority && basePath.isEmpty {
                return "/" + relativePath
            }
            return basePath.merging(relativePath: relativePath)
        }

        var newPath = appendedPath()

        let hasTrailingSlash = newPath.utf8.last == ._slash
        let isDirectory: Bool
        switch directoryHint {
        case .isDirectory:
            isDirectory = true
        case .notDirectory:
            isDirectory = false
        case .checkFileSystem:
            #if !NO_FILESYSTEM
            // We can only check file system if the URL is a file URL
            if isFileURL {
                let filePath: String
                if newPath.utf8.first == ._slash {
                    filePath = Self.fileSystemPath(for: newPath)
                } else {
                    filePath = Self.fileSystemPath(for: mergedPath(for: newPath))
                }
                isDirectory = Self.isDirectory(filePath)
            } else {
                // For web addresses, trust the trailing slash
                isDirectory = hasTrailingSlash
            }
            #else // !NO_FILESYSTEM
            isDirectory = hasTrailingSlash
            #endif // !NO_FILESYSTEM
        case .inferFromPath:
            isDirectory = hasTrailingSlash
        }
        if isDirectory && newPath.utf8.last != ._slash {
            newPath += "/"
        }

        var components = URLComponents(parseInfo: _parseInfo)
        components.percentEncodedPath = newPath
        let string = components._uncheckedString(original: false)
        return _SwiftURL(stringOrEmpty: string, relativeTo: baseURL)?.url
    }

#if !NO_FILESYSTEM

    private static func isDirectory(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        #if os(Windows)
        let path = path.replacing(._slash, with: ._backslash)
        return (try? path.withNTPathRepresentation { pwszPath in
            // If path points to a symlink (reparse point), get a handle to
            // the symlink itself using FILE_FLAG_OPEN_REPARSE_POINT.
            let handle = CreateFileW(pwszPath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nil)
            guard handle != INVALID_HANDLE_VALUE else { return false }
            defer { CloseHandle(handle) }
            var info: BY_HANDLE_FILE_INFORMATION = BY_HANDLE_FILE_INFORMATION()
            guard GetFileInformationByHandle(handle, &info) else { return false }
            if (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) == FILE_ATTRIBUTE_REPARSE_POINT { return false }
            return (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == FILE_ATTRIBUTE_DIRECTORY
        }) ?? false
        #else
        // FileManager uses stat() to check if the file exists.
        // URL historically won't follow a symlink at the end
        // of the path, so use lstat() here instead.
        return path.withFileSystemRepresentation { fsRep in
            guard let fsRep else { return false }
            var fileInfo = stat()
            guard lstat(fsRep, &fileInfo) == 0 else { return false }
            return (mode_t(fileInfo.st_mode) & S_IFMT) == S_IFDIR
        }
        #endif
    }

    private static func currentDirectoryOrNil() -> URL? {
        let path: String? = FileManager.default.currentDirectoryPath
        guard var filePath = path else {
            return nil
        }
        #if os(Windows)
        filePath = filePath.replacing(._backslash, with: ._slash)
        #endif
        guard URL.isAbsolute(standardizing: &filePath) else {
            return nil
        }
        return URL(filePath: filePath, directoryHint: .isDirectory)
    }

#endif

    /// True if the URL's relative path would resolve against a base URL path
    private var pathResolvesAgainstBase: Bool {
        return _parseInfo.scheme == nil && !hasAuthority && _parseInfo.path.utf8.first != ._slash
    }

    func deletingLastPathComponent() -> URL? {
        let path = relativePath(percentEncoded: true)
        let shouldAppendDotDot = (
            pathResolvesAgainstBase && (
                path.isEmpty
                || path.lastPathComponent == "."
                || path.lastPathComponent == ".."
            )
        )

        var newPath = path
        if newPath.lastPathComponent != ".." {
            newPath = newPath.deletingLastPathComponent()
        }
        if shouldAppendDotDot {
            newPath = newPath.appendingPathComponent("..")
        }
        if newPath.isEmpty && pathResolvesAgainstBase {
            newPath = "."
        }
        // .deletingLastPathComponent() removes the trailing "/", but we know it's a directory
        if !newPath.isEmpty && newPath.utf8.last != ._slash {
            newPath += "/"
        }
        var components = URLComponents(parseInfo: _parseInfo)
        /// Compatibility path for apps that loop on:
        /// `url = url.deletingPathComponent().standardized` until `url.path.isEmpty`.
        ///
        /// This used to work due to a combination of bugs where:
        /// `URL("/").deletingLastPathComponent == URL("/../")`
        /// `URL("/../").standardized == URL("")`
        #if FOUNDATION_FRAMEWORK
        if URL.compatibility1 && path == "/" {
            components.percentEncodedPath = "/../"
        } else {
            components.percentEncodedPath = newPath
        }
        #else
        components.percentEncodedPath = newPath
        #endif
        let string = components._uncheckedString(original: false)
        return _SwiftURL(stringOrEmpty: string, relativeTo: baseURL)?.url
    }
    
    internal func appendingPathExtension(_ pathExtension: String, compatibility: Bool) -> URL? {
        guard !pathExtension.isEmpty, !_parseInfo.path.isEmpty else {
            return nil
        }
        #if FOUNDATION_FRAMEWORK
        var pathExtension = pathExtension
        if isFileURL {
            // Use the file system (decomposed) representation
            pathExtension = pathExtension.fileSystemRepresentation
        }
        #endif
        var components = URLComponents(parseInfo: _parseInfo)
        // pathExtension might need to be percent-encoded
        let encodedExtension = if compatibility {
            Parser.percentEncode(pathComponent: pathExtension, including: [._semicolon])
        } else {
            Parser.percentEncode(pathComponent: pathExtension)
        }
        let newPath = components.percentEncodedPath.appendingPathExtension(encodedExtension)
        components.percentEncodedPath = newPath
        let string = components._uncheckedString(original: false)
        return _SwiftURL(string: string, relativeTo: baseURL)?.url
    }

    func appendingPathExtension(_ pathExtension: String) -> URL? {
        return appendingPathExtension(pathExtension, compatibility: false)
    }

    func deletingPathExtension() -> URL? {
        guard !_parseInfo.path.isEmpty else { return nil }
        var components = URLComponents(parseInfo: _parseInfo)
        let newPath = components.percentEncodedPath.deletingPathExtension()
        components.percentEncodedPath = newPath
        let string = components._uncheckedString(original: false)
        return _SwiftURL(stringOrEmpty: string, relativeTo: baseURL)?.url
    }
    
    var standardized: URL? {
        /// Compatibility path for apps that loop on:
        /// `url = url.deletingPathComponent().standardized` until `url.path.isEmpty`.
        ///
        /// This used to work due to a combination of bugs where:
        /// `URL("/").deletingLastPathComponent == URL("/../")`
        /// `URL("/../").standardized == URL("")`
        #if FOUNDATION_FRAMEWORK
        guard isDecomposable else { return nil }
        let newPath = if URL.compatibility1 && _parseInfo.path == "/../" {
            ""
        } else {
            String(_parseInfo.path).removingDotSegments
        }
        #else
        let newPath = String(_parseInfo.path).removingDotSegments
        #endif
        var components = URLComponents(parseInfo: _parseInfo)
        components.percentEncodedPath = newPath.removingDotSegments
        if components.scheme != nil {
            // Standardize scheme:// to scheme:///
            if newPath.isEmpty && _parseInfo.netLocationRange?.isEmpty ?? false {
                components.percentEncodedPath = "/"
            }
            // Standardize scheme:/path to scheme:///path
            if components.encodedHost == nil {
                components.encodedHost = ""
            }
        }
        let string = components._uncheckedString(original: false)
        return _SwiftURL(stringOrEmpty: string, relativeTo: baseURL)?.url
    }

#if !NO_FILESYSTEM
    var standardizedFileURL: URL? {
        guard isFileURL, !fileSystemPath().isEmpty else { return nil }
        return URL(filePath: fileSystemPath().standardizingPath, directoryHint: hasDirectoryPath ? .isDirectory : .notDirectory)
    }

    func resolvingSymlinksInPath() -> URL? {
        guard isFileURL, !fileSystemPath().isEmpty else { return nil }
        return URL(filePath: fileSystemPath().resolvingSymlinksInPath, directoryHint: hasDirectoryPath ? .isDirectory : .notDirectory)
    }
#endif

    private static let dataSchemeUTF8 = Array("data".utf8)
    var description: String {
        var urlString = relativeString
        if let scheme, scheme.lowercased().utf8.elementsEqual(Self.dataSchemeUTF8), urlString.utf8.count > 128 {
            let prefix = urlString.utf8.prefix(120)
            let suffix = urlString.utf8.suffix(8)
            urlString = "\(prefix) ... \(suffix)"
        }
        if let baseURL {
            return "\(urlString) -- \(baseURL.description)"
        }
        return urlString
    }

    var debugDescription: String {
        return description
    }

#if FOUNDATION_FRAMEWORK

    func bridgeToNSURL() -> NSURL {
        if foundation_swift_nsurl_enabled() {
            return _NSSwiftURL(url: self)
        }
        return _nsurl
    }

    internal func isFileReferenceURL() -> Bool {
        #if NO_FILESYSTEM
        return false
        #else
        return isFileURL && _parseInfo.pathHasFileID
        #endif
    }

    internal func convertingFileReference() -> any _URLProtocol & AnyObject {
        #if NO_FILESYSTEM
        return self
        #else
        guard isFileReferenceURL() else { return self }
        guard let url = bridgeToNSURL().filePathURL else {
            return _SwiftURL(string: "com-apple-unresolvable-file-reference-url:")!
        }
        return url._url
        #endif
    }

#else

    internal func convertingFileReference() -> _SwiftURL {
        return self
    }

#endif // FOUNDATION_FRAMEWORK

    static func == (lhs: _SwiftURL, rhs: _SwiftURL) -> Bool {
        return lhs.relativeString == rhs.relativeString && lhs.baseURL == rhs.baseURL
    }

    func hash(into hasher: inout Hasher) {
        // Historically, the CF/NSURL hash only includes the relative string
        hasher.combine(relativeString)
    }

    /// Convenience for constructing a URL string from components without validation.
    private struct URLStringBuilder {
        typealias Parser = _SwiftURL.Parser
        var scheme: String?
        var user: String?
        var password: String?
        var host: String?
        var portString: String?
        var path: String
        var query: String?
        var fragment: String?

        var hasAuthority: Bool {
            return user != nil || password != nil || host != nil || portString != nil
        }

        init(parseInfo: URLParseInfo, original: Bool) {
            let encodedComponents = original ? parseInfo.encodedComponents : []
            if let scheme = parseInfo.scheme {
                self.scheme = String(scheme)
            }
            if let user = parseInfo.user{
                self.user = encodedComponents.contains(.user) ? Parser.percentDecode(user) : String(user)
            }
            if let password = parseInfo.password {
                self.password = encodedComponents.contains(.password) ? Parser.percentDecode(password) : String(password)
            }
            if let host = parseInfo.host {
                // We don't need to check for IDNA-encoding since only CFURL uses
                // the original string, and CFURL does not support INDA-encoding.
                self.host = encodedComponents.contains(.host) ? Parser.percentDecode(host) : String(host)
            }
            if let portString = parseInfo.portString {
                self.portString = String(portString)
            }
            self.path = encodedComponents.contains(.path) ? Parser.percentDecode(parseInfo.path) ?? "" : String(parseInfo.path)
            if let query = parseInfo.query {
                self.query = encodedComponents.contains(.query) ? Parser.percentDecode(query) : String(query)
            }
            if let fragment = parseInfo.fragment {
                self.fragment = encodedComponents.contains(.fragment) ? Parser.percentDecode(fragment) : String(fragment)
            }
        }

        var string: String {
            var result = ""
            if let scheme {
                result += "\(scheme):"
            }
            if hasAuthority {
                result += "//"
            }
            if let user {
                result += user
            }
            if let password {
                result += ":\(password)"
            }
            if user != nil || password != nil {
                result += "@"
            }
            if let host {
                result += host
            }
            if let portString {
                result += ":\(portString)"
            }
            result += path
            if let query, !query.isEmpty {
                result += "?\(query)"
            }
            if let fragment {
                result += "#\(fragment)"
            }
            return result
        }

        var removingDotSegments: URLStringBuilder {
            var result = self
            result.path = result.path.removingDotSegments
            return result
        }
    }

}

private extension String {
    var fileSystemRepresentation: String {
        #if FOUNDATION_FRAMEWORK
        return withFileSystemRepresentation { fsRep in
            guard let fsRep else {
                return self
            }
            return String(cString: fsRep)
        }
        #else
        return self
        #endif
    }
}

#if FOUNDATION_FRAMEWORK
internal import CoreFoundation_Private.CFURL

/// This conformance is only needed in `FOUNDATION_FRAMEWORK`,
/// where `URL` can be implemented by a few different classes.
extension _SwiftURL: _URLProtocol {}

extension _SwiftURL {
    private static func _makeNSURL(from parseInfo: URLParseInfo, baseURL: URL?) -> NSURL {
        return _makeCFURL(from: parseInfo, baseURL: baseURL as CFURL?) as NSURL
    }

    struct _CFURLFlags: OptionSet {
        let rawValue: UInt32

        // These must match the CFURL flags defined in CFURL.m
        static let hasScheme            = _CFURLFlags(rawValue: 0x00000001)
        static let hasUser              = _CFURLFlags(rawValue: 0x00000002)
        static let hasPassword          = _CFURLFlags(rawValue: 0x00000004)
        static let hasHost              = _CFURLFlags(rawValue: 0x00000008)
        static let hasPort              = _CFURLFlags(rawValue: 0x00000010)
        static let hasPath              = _CFURLFlags(rawValue: 0x00000020)
        static let hasParameters        = _CFURLFlags(rawValue: 0x00000040) // Unused
        static let hasQuery             = _CFURLFlags(rawValue: 0x00000080)
        static let hasFragment          = _CFURLFlags(rawValue: 0x00000100)
        static let isIPLiteral          = _CFURLFlags(rawValue: 0x00000400)
        static let isDirectory          = _CFURLFlags(rawValue: 0x00000800)
        static let isCanonicalFileURL   = _CFURLFlags(rawValue: 0x00001000) // Unused
        static let pathHasFileID        = _CFURLFlags(rawValue: 0x00002000)
        static let isDecomposable       = _CFURLFlags(rawValue: 0x00004000)
        static let posixAndURLPathsMatch        = _CFURLFlags(rawValue: 0x00008000)
        static let originalAndURLStringsMatch   = _CFURLFlags(rawValue: 0x00010000)
        static let originatedFromSwift          = _CFURLFlags(rawValue: 0x00020000)
    }

    private static func _makeCFURL(from parseInfo: URLParseInfo, baseURL: CFURL?) -> CFURL {
        let string = parseInfo.urlString
        var ranges = [CFRange]()
        var flags: _CFURLFlags = [
            .originalAndURLStringsMatch,
            .originatedFromSwift,
        ]

        // CFURL considers a URL decomposable if it does not have a scheme
        // or if there is a slash directly following the scheme.
        if parseInfo.scheme == nil || parseInfo.hasAuthority || parseInfo.path.utf8.first == ._slash {
            flags.insert(.isDecomposable)
        }

        if let schemeRange = parseInfo.schemeRange {
            flags.insert(.hasScheme)
            let nsRange = string._toRelativeNSRange(schemeRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let userRange = parseInfo.userRange {
            flags.insert(.hasUser)
            let nsRange = string._toRelativeNSRange(userRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let passwordRange = parseInfo.passwordRange {
            flags.insert(.hasPassword)
            let nsRange = string._toRelativeNSRange(passwordRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if parseInfo.portRange != nil {
            flags.insert(.hasPort)
        }

        // CFURL considers an empty host nil unless there's another authority component
        if let hostRange = parseInfo.hostRange,
           (!hostRange.isEmpty || !flags.isDisjoint(with: [.hasUser, .hasPassword, .hasPort])) {
            flags.insert(.hasHost)
            let nsRange = string._toRelativeNSRange(hostRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let portRange = parseInfo.portRange {
            let nsRange = string._toRelativeNSRange(portRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if !parseInfo.path.isEmpty || parseInfo.netLocationRange?.isEmpty == false {
            flags.insert(.hasPath)
            if let pathRange = parseInfo.pathRange {
                let nsRange = string._toRelativeNSRange(pathRange)
                ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
            } else {
                ranges.append(CFRange(location: kCFNotFound, length: 0))
            }
        }

        if let queryRange = parseInfo.queryRange {
            flags.insert(.hasQuery)
            let nsRange = string._toRelativeNSRange(queryRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let fragmentRange = parseInfo.fragmentRange {
            flags.insert(.hasFragment)
            let nsRange = string._toRelativeNSRange(fragmentRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        let path = parseInfo.path.utf8
        let isDirectory = path.last == UInt8(ascii: "/")

        if parseInfo.isIPLiteral {
            flags.insert(.isIPLiteral)
        }
        if isDirectory {
            flags.insert(.isDirectory)
        }
        if parseInfo.pathHasFileID {
            flags.insert(.pathHasFileID)
        }
        if !isDirectory && !parseInfo.path.utf8.contains(UInt8(ascii: "%")) {
            flags.insert(.posixAndURLPathsMatch)
        }

        return ranges.withUnsafeBufferPointer {
            _CFURLCreateWithRangesAndFlags(string as CFString, $0.baseAddress!, UInt8($0.count), flags.rawValue, baseURL)
        }
    }
}
#endif
