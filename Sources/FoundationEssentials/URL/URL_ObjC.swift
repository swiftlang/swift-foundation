//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

internal import _ForSwiftFoundation

@objc
extension NSURL {

    /// `encodingInvalidCharacters: false` is equivalent to `CFURLCreateWithString`.
    ///
    /// `encodingInvalidCharacters: true` is equivalent to `CFURLCreateWithBytes`.
    ///
    /// `forceBaseURL` is used for compatibility-mode `CFURLCreateAbsoluteURLWithBytes`.
    /// Usually, we drop the base URL if the relative string contains a scheme, but in this specific case,
    /// we need to keep the base URL around until with call `.compatibilityAbsoluteURL`,
    /// which has special behavior for a relative and base URL with the same scheme.
    static func _cfurlWith(string: String, encoding: CFStringEncoding, relativeToURL base: URL?, encodingInvalidCharacters: Bool, forceBaseURL: Bool) -> NSURL? {
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        guard let url = _SwiftURL(stringOrEmpty: string, relativeTo: base, encodingInvalidCharacters: encodingInvalidCharacters, encoding: encoding, compatibility: true, forceBaseURL: forceBaseURL) else { return nil }
        return _NSSwiftURL(url: url)
    }

    /// Equivalent to `+[NSURL URLWithString:relativeToURL:encodingInvalidCharacters:]`
    static func _urlWith(string: String, relativeToURL base: URL?, encodingInvalidCharacters: Bool) -> NSURL? {
        guard let url = _SwiftURL(stringOrEmpty: string, relativeTo: base, encodingInvalidCharacters: encodingInvalidCharacters) else { return nil }
        return _NSSwiftURL(url: url)
    }

    /// Equivalent to `+[NSURL URLWithDataRepresentation:relativeToURL:]` or
    /// `+[NSURL absoluteURLWithDataRepresentation:relativeToURL:]` based
    /// on the value of `isAbsolute`.
    ///
    /// Uses the same parsing logic as `CFURLCreateWithBytes`.
    static func _urlWith(dataRepresentation: Data, relativeToURL base: URL?, isAbsolute: Bool) -> NSURL? {
        guard let url = _SwiftURL(dataRepresentation: dataRepresentation, relativeTo: base, isAbsolute: isAbsolute) else { return nil }
        return _NSSwiftURL(url: url)
    }

    /// Equivalent to `+[NSURL fileURLWithPath:relativeToURL:]`
    static func _fileURLWith(path: String, relativeToURL base: URL?) -> NSURL? {
        if path.isEmpty {
            return base as NSURL?
        }
        let directoryHint: URL.DirectoryHint = path.utf8.last == ._slash ? .isDirectory : .checkFileSystem
        let url = _SwiftURL(filePath: path, directoryHint: directoryHint, relativeTo: base)
        return _NSSwiftURL(url: url)
    }

    /// Equivalent to `+[NSURL fileURLWithPath:isDirectory:relativeToURL:]`
    static func _fileURLWith(path: String, isDirectory: Bool, relativeToURL base: URL?) -> NSURL? {
        if path.isEmpty {
            return base as NSURL?
        }
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        let url = _SwiftURL(filePath: path, directoryHint: directoryHint, relativeTo: base)
        return _NSSwiftURL(url: url)
    }

    /// Equivalent to `CFURLCreateWithFileSystemPathRelativeToBase`.
    static func _fileURLWith(path: String, pathStyle: CFURLPathStyle, isDirectory: Bool, relativeToURL base: URL?) -> NSURL? {
        if path.isEmpty {
            return base as NSURL?
        }
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        let url = _SwiftURL(filePath: path, pathStyle: pathStyle.swiftValue, directoryHint: directoryHint, relativeTo: base)
        return _NSSwiftURL(url: url)
    }

}


@objc(_NSSwiftURL)
internal class _NSSwiftURL: _NSURLBridge, @unchecked Sendable {
    let url: _SwiftURL
    let string: String

    // Important flags for NS/CFURL-specific logic
    let isDecomposable: Bool
    let hasNetLocation: Bool
    let hasPath: Bool

    init(url: _SwiftURL) {
        self.url = url

        // Store the string here to prevent a premature
        // release when it's bridged to an NS or CFString.
        self.string = url._parseInfo.urlString

        self.isDecomposable = url.isDecomposable
        self.hasNetLocation = (url._parseInfo.netLocationRange?.isEmpty == false)
        self.hasPath = self.isDecomposable && (!url._parseInfo.path.isEmpty || self.hasNetLocation)
        super.init()
    }

    override var classForCoder: AnyClass {
        NSURL.self
    }

    override static var supportsSecureCoding: Bool { true }

    required init?(coder: NSCoder) {
        fatalError("Only NSURL should be encoded in an archive")
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? _NSSwiftURL {
            return url == other.url
        } else if let other = object as? NSURL {
            return url == other._trueSelf()._swiftURL
        } else {
            return false
        }
    }

    // Note: copy(with:) is just a retain in NSURL

    override var hash: Int {
        return url.hashValue
    }

    override var description: String {
        return url.description
    }

    override var dataRepresentation: Data {
        return url.dataRepresentation
    }

    override var absoluteString: String? {
        guard !relativeString.isEmpty else { return baseURL?.absoluteString ?? "" } // Compatibility behavior
        return url.absoluteString
    }

    override var relativeString: String {
        return string
    }

    override var baseURL: URL? {
        return url.baseURL
    }

    override var absoluteURL: URL? {
        guard baseURL != nil else { return URL(self) }
        guard !relativeString.isEmpty else { return baseURL } // Compatibility behavior
        #if !NO_FILESYSTEM
        if let baseURL, baseURL.isFileReferenceURL(), !baseURL.hasDirectoryPath {
            guard let baseFilePathURL = (baseURL as NSURL).filePathURL else {
                return nil
            }
            return _SwiftURL(string: relativeString, relativeTo: baseFilePathURL)?.absoluteURL
        }
        #endif
        return url.absoluteURL
    }

    override var scheme: String? {
        url.scheme
    }

    // Note: This is NOT the same as CFURLCopyResourceSpecifier.
    override var resourceSpecifier: String? {
        guard scheme != nil && baseURL == nil else {
            return relativeString
        }
        // We have a scheme and no base
        guard isDecomposable else {
            return _cfurlResourceSpecifier
        }
        var result: String?
        if let _netLocation {
            result = "//" + _netLocation
        }
        if let path = _relativePath(true) {
            result = (result ?? "") + path
        }
        if let _cfurlResourceSpecifier {
            result = (result ?? "") + _cfurlResourceSpecifier
        }
        return result
    }

    override var user: String? {
        url.user
    }

    override var password: String? {
        url.password
    }

    override var host: String? {
        url.host
    }

    override var port: NSNumber? {
        url.port as NSNumber?
    }

    override var path: String? {
        guard isDecomposable else {
            return nil
        }
        if isFileURL {
            return _fileSystemPath()
        } else {
            return url.path
        }
    }

    #if !NO_FILESYSTEM
    private func filePath(for fileReferencePath: String) -> String? {
        var fileReferencePath = fileReferencePath
        return fileReferencePath.withUTF8 { buffer -> String? in
            guard buffer.starts(with: URL.fileIDPrefix) else {
                return nil
            }
            let volumeIDStart = URL.fileIDPrefix.count
            guard let volumeIDEnd = buffer[volumeIDStart...].firstIndex(of: ._dot) else {
                return nil
            }
            let volumeIDStr = String(decoding: buffer[volumeIDStart..<volumeIDEnd], as: UTF8.self)
            guard let volumeID = Int64(volumeIDStr) else {
                return nil
            }
            let fileIDStart = volumeIDEnd + 1
            let fileIDEnd = buffer[fileIDStart...].firstIndex(of: ._slash) ?? buffer.endIndex
            let fileIDStr = String(decoding: buffer[fileIDStart..<fileIDEnd], as: UTF8.self)
            let fileID = Int64(fileIDStr) ?? Int64(0)
            guard let path = __CFURLCreatePathForFileID(volumeID, fileID) as String?, !path.isEmpty else {
                return nil
            }
            guard let urlPath = RFC3986Parser.percentEncode(path, component: .path) else {
                return nil
            }
            let fullPath = urlPath + String(decoding: buffer[fileIDEnd...], as: UTF8.self)
            if let resolveFlags = query?._queryResolveFlags(),
               resolveFlags != 0 {
                return fullPath._insertingPathResolveFlags(resolveFlags)
            }
            return fullPath
        }
    }
    #endif

    private func _fileSystemPath(_ pathStyle: URL.PathStyle = URL.defaultPathStyle, resolveAgainstBase: Bool = true) -> String? {
        guard hasPath else {
            return resolveAgainstBase ? baseURL?.fileSystemPath(style: pathStyle, resolveAgainstBase: true, compatibility: true) : nil
        }
        guard !url._parseInfo.path.isEmpty else {
            if resolveAgainstBase, let baseURL {
                return baseURL.fileSystemPath(style: pathStyle, resolveAgainstBase: true, compatibility: true).deletingLastPathComponent()
            }
            return ""
        }
        #if !NO_FILESYSTEM
        if (!resolveAgainstBase || baseURL == nil) && isFileReferenceURL() {
            guard let fileReferencePath = filePath(for: url.relativePath(percentEncoded: true)) else {
                return nil
            }
            return _SwiftURL.fileSystemPath(for: fileReferencePath, style: pathStyle, compatibility: true)
        }
        #endif
        return url.fileSystemPath(style: pathStyle, resolveAgainstBase: resolveAgainstBase, compatibility: true)
    }

    override var relativePath: String? {
        return _fileSystemPath(resolveAgainstBase: false)
    }

    override var query: String? {
        guard isDecomposable else {
            return nil
        }
        return url.query
    }

    override var fragment: String? {
        guard isDecomposable else {
            return nil
        }
        return url.fragment
    }

    override var hasDirectoryPath: Bool {
        if url.hasDirectoryPath {
            return true
        }
        return url.path.isEmpty && baseURL?.hasDirectoryPath ?? false
    }

    override var isFileURL: Bool {
        url.isFileURL
    }

    override var standardized: URL? {
        return url.standardized ?? URL(self)
    }

    #if !NO_FILESYSTEM
    override func isFileReferenceURL() -> Bool {
        url.isFileReferenceURL()
    }
    #endif

    // Note: fileReferenceURL() calls into NSURL since CFURL is needed

    // Note: filePathURL calls into NSURL since CFURL is needed

    // Used by CFURL, which expects "" on empty path
    override var _lastPathComponent: String? {
        #if !NO_FILESYSTEM
        if isFileReferenceURL(), let filePathURL {
            return (filePathURL as NSURL)._lastPathComponent
        }
        #endif
        guard hasPath else {
            return ""
        }
        let result = url.lastPathComponent
        if result == "/" && url._parseInfo.path != "/" { return "" }
        return result
    }

    // NSURL and CFURL share exact behavior for this method.
    override var deletingLastPathComponent: URL? {
        #if !NO_FILESYSTEM
        if isFileReferenceURL() {
            return filePathURL?.deletingLastPathComponent()
        }
        #endif
        guard hasPath else {
            return nil
        }
        if url.path == "/" || url.path == "/." || url.lastPathComponent == ".." {
            return url.appending(path: "../", directoryHint: .isDirectory)
        }
        if url.lastPathComponent == "." {
            var comp = URLComponents(parseInfo: url._parseInfo)
            let newPath = comp.percentEncodedPath._droppingTrailingSlashes.dropLast() + "../"
            comp.percentEncodedPath = String(newPath)
            if let result = comp.url(relativeTo: baseURL) {
                return result
            }
        }
        return url.deletingLastPathComponent() ?? URL(self)
    }

    // NSURL and CFURL share exact behavior for this method.
    override var deletingPathExtension: URL? {
        #if !NO_FILESYSTEM
        if isFileReferenceURL() {
            return filePathURL?.deletingPathExtension()
        }
        #endif
        guard hasPath else {
            return nil
        }
        return url.deletingPathExtension() ?? URL(self)
    }

}

// MARK: - Internal overrides for NSURL

extension _NSSwiftURL {

    // Don't override these appending methods directly so we can
    // check input and throw an exception in ObjC if necessary.

    // NSURL and CFURL share exact behavior for this method.
    override func _URL(byAppendingPathComponent pathComponent: String, isDirectory: Bool, encodingSlashes: Bool) -> URL? {
        if let nulIndex = pathComponent.utf8.firstIndex(of: 0),
           !pathComponent[nulIndex...].utf8.allSatisfy({ $0 == 0 }) {
            return nil
        }
        guard hasPath else {
            return nil
        }
        var url = url
        #if !NO_FILESYSTEM
        if isFileReferenceURL(), let filePathSwiftURL = filePathURL?._swiftURL  {
            url = filePathSwiftURL
        }
        #endif
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        return url.appending(path: pathComponent, directoryHint: directoryHint, encodingSlashes: encodingSlashes, compatibility: true)
    }

    // NSURL and CFURL share exact behavior for this method.
    override func _URL(byAppendingPathExtension pathExtension: String) -> URL? {
        guard !pathExtension.isEmpty else {
            return self as URL
        }
        guard hasPath else {
            return nil
        }
        var url = url
        #if !NO_FILESYSTEM
        if isFileReferenceURL() {
            guard let filePathSwiftURL = filePathURL?._swiftURL else {
                return nil
            }
            url = filePathSwiftURL
        }
        #endif
        return url.appendingPathExtension(pathExtension, compatibility: true) ?? URL(self)
    }

}

// MARK: - Internal overrides for CFURL

extension CFURLPathStyle {
    var swiftValue: URL.PathStyle {
        return switch self {
        case .cfurlposixPathStyle: .posix
        case .cfurlWindowsPathStyle: .windows
        case .cfurlhfsPathStyle: fatalError("HFS path style is deprecated")
        default: URL.defaultPathStyle
        }
    }
}

extension _NSSwiftURL {

    override var _originalString: String {
        return url.originalString
    }

    override var _encoding: CFStringEncoding {
        CFStringConvertNSStringEncodingToEncoding(url._encoding.rawValue)
    }

    override var _resourceInfoPtr: UnsafeMutableRawPointer? {
        get {
            url._resourceInfo.ref.withLock {
                guard let cf = $0 else { return nil }
                return Unmanaged<CFTypeRef>.passUnretained(cf).toOpaque()
            }
        }
        set {
            url._resourceInfo.ref.withLockUnchecked {
                guard let newValue else {
                    $0 = nil
                    return
                }
                // URL._resourceInfo is responsible for releasing this on deinit
                $0 = Unmanaged<CFTypeRef>.fromOpaque(newValue).takeUnretainedValue()
            }
        }
    }

    override var _compatibilityAbsolute: URL {
        return url.compatibilityAbsoluteURL ?? URL(self)
    }

    override var _isDecomposable: Bool {
        return isDecomposable
    }

    override var _netLocation: String? {
        guard let netLocation = url.netLocation,
              !netLocation.isEmpty else {
            return nil
        }
        return netLocation
    }

    override var _cfurlResourceSpecifier: String? {
        guard isDecomposable else {
            // Return everything after the scheme
            guard let colonIndex = relativeString.utf8.firstIndex(where: { $0 == ._colon }) else {
                return nil
            }
            let start = relativeString.utf8.index(after: colonIndex)
            return String(relativeString[start...])
        }
        var result: String?
        if let query = url._parseInfo.query, !query.isEmpty {
            result = "?\(query)"
        }
        if let fragment = url._parseInfo.fragment {
            result = (result ?? "") + "#\(fragment)"
        }
        return result
    }

    override func _user(_ percentEncoded: Bool) -> String? {
        url.user(percentEncoded: percentEncoded)
    }

    override func _password(_ percentEncoded: Bool) -> String? {
        url.password(percentEncoded: percentEncoded)
    }

    override func _host(_ percentEncoded: Bool) -> String? {
        url.host(percentEncoded: percentEncoded)
    }

    override func _relativePath(_ percentEncoded: Bool) -> String? {
        guard hasPath else {
            return nil
        }
        return url.relativePath(percentEncoded: percentEncoded)
    }

    override func _fileSystemPath(_ pathStyle: CFURLPathStyle, resolveAgainstBase: Bool) -> String? {
        let path = _fileSystemPath(pathStyle.swiftValue, resolveAgainstBase: resolveAgainstBase)
        if pathStyle == .cfurlWindowsPathStyle {
            return path?.replacing(._slash, with: ._backslash)
        }
        return path
    }

    override func _query(_ charsToLeaveEscaped: String?) -> String? {
        guard isDecomposable, let query else {
            return nil
        }
        guard let charsToLeaveEscaped else {
            return query
        }
        return RFC3986Parser.percentDecode(query, excluding: Set(charsToLeaveEscaped.utf8))
    }

    override func _fragment(_ charsToLeaveEscaped: String?) -> String? {
        guard isDecomposable, let fragment else {
            return nil
        }
        guard let charsToLeaveEscaped else {
            return fragment
        }
        return RFC3986Parser.percentDecode(fragment, excluding: Set(charsToLeaveEscaped.utf8))
    }

    private func _nonDecomposableRange(for component: CFURLComponentType, rangeIncludingSeparators: UnsafeMutablePointer<CFRange>) -> CFRange {
        // URL must be of the form "scheme:resource-specifier".
        guard let scheme else {
            rangeIncludingSeparators.pointee = CFRange(location: kCFNotFound, length: 0)
            return CFRange(location: kCFNotFound, length: 0)
        }
        // Scheme must be ASCII, so UTF-8 length can be used.
        let schemeLength = scheme.utf8.count
        switch component {
        case .scheme:
            rangeIncludingSeparators.pointee = CFRange(location: 0, length: schemeLength + 1)
            return CFRange(location: 0, length: schemeLength)
        case .resourceSpecifier:
            let stringLength = url.originalString.lengthOfBytes(using: url._encoding)
            if schemeLength + 1 == stringLength {
                rangeIncludingSeparators.pointee = CFRange(location: stringLength, length: 0)
                return CFRange(location: kCFNotFound, length: 0)
            }
            rangeIncludingSeparators.pointee = CFRange(location: schemeLength, length: stringLength - schemeLength)
            return CFRange(location: schemeLength + 1, length: stringLength - schemeLength - 1)
        default:
            rangeIncludingSeparators.pointee = CFRange(location: kCFNotFound, length: 0)
            return CFRange(location: kCFNotFound, length: 0)
        }
    }

    private func _decomposableRange(for component: CFURLComponentType, rangeIncludingSeparators: UnsafeMutablePointer<CFRange>) -> CFRange {
        let parseInfo = if url.encodedComponents.isEmpty {
            url._parseInfo
        } else {
            RFC3986Parser.rawParse(urlString: url.originalString)
        }
        guard let parseInfo else {
            rangeIncludingSeparators.pointee = CFRange(location: kCFNotFound, length: 0)
            return CFRange(location: kCFNotFound, length: 0)
        }
        let string = url.originalString
        let encoding = url._encoding
        switch component {
        case .scheme:
            if let scheme = parseInfo.scheme {
                // Scheme must be ASCII, so we can use UTF8 length.
                let schemeLength = scheme.utf8.count
                var afterSeparatorLength = parseInfo.hasAuthority ? 3 : 1
                if !hasNetLocation && !hasPath {
                    afterSeparatorLength = 0
                }
                rangeIncludingSeparators.pointee = CFRange(location: 0, length: schemeLength + afterSeparatorLength)
                return CFRange(location: 0, length: schemeLength)
            }
        case .netLocation:
            if let netLocationRange = parseInfo.netLocationRange,
               !netLocationRange.isEmpty {
                let beforeLength = string[..<netLocationRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[netLocationRange].lengthOfBytes(using: encoding)
                let separatorLength = 2 + (parseInfo.schemeRange == nil ? 0 : 1)
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - separatorLength, length: componentLength + separatorLength)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .path:
            if let pathRange = parseInfo.pathRange, hasPath {
                let beforeLength = string[..<pathRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[pathRange].lengthOfBytes(using: encoding)
                var beforeSeparatorLength = (parseInfo.schemeRange != nil) ? 1 : 0
                if parseInfo.hasAuthority {
                    if parseInfo.netLocationRange?.isEmpty == true {
                        beforeSeparatorLength += 2
                    } else {
                        beforeSeparatorLength = 0
                    }
                }
                let afterSeparatorLength = (parseInfo.queryRange != nil || parseInfo.fragmentRange != nil) ? 1 : 0
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - beforeSeparatorLength, length: beforeSeparatorLength + componentLength + afterSeparatorLength)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .resourceSpecifier:
            if let resourceSpecifierRange = parseInfo.cfResourceSpecifierRange {
                let beforeLength = string[..<resourceSpecifierRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[resourceSpecifierRange].lengthOfBytes(using: encoding)
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - 1, length: componentLength + 1)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .user:
            if let userRange = parseInfo.userRange {
                let beforeLength = string[..<userRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[userRange].lengthOfBytes(using: encoding)
                let beforeSeparatorLength = 2 + (parseInfo.schemeRange == nil ? 0 : 1)
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - beforeSeparatorLength, length: beforeSeparatorLength + componentLength + 1)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .password:
            if let passwordRange = parseInfo.passwordRange {
                let beforeLength = string[..<passwordRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[passwordRange].lengthOfBytes(using: encoding)
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - 1, length: componentLength + 2)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .userInfo:
            if let startIndex = parseInfo.userRange?.lowerBound
                ?? parseInfo.passwordRange?.lowerBound,
               let endIndex = parseInfo.passwordRange?.upperBound
                ?? parseInfo.userRange?.upperBound {
                let beforeLength = string[..<startIndex].lengthOfBytes(using: encoding)
                let componentLength = string[startIndex..<endIndex].lengthOfBytes(using: encoding)
                let beforeSeparatorLength = 2 + (parseInfo.schemeRange == nil ? 0 : 1)
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - beforeSeparatorLength, length: beforeSeparatorLength + componentLength + 1)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .host:
            if let hostRange = parseInfo.hostRange,
               host != nil {
                let beforeLength = string[..<hostRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[hostRange].lengthOfBytes(using: encoding)
                let beforeSeparatorLength = if parseInfo.userRange == nil && parseInfo.passwordRange == nil {
                    2 + (parseInfo.schemeRange == nil ? 0 : 1)
                } else {
                    1
                }
                let afterSeparatorLength = if parseInfo.portRange == nil {
                    0
                } else {
                    1
                }
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - beforeSeparatorLength, length: beforeSeparatorLength + componentLength + afterSeparatorLength)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .port:
            if let portRange = parseInfo.portRange {
                let beforeLength = string[..<portRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[portRange].lengthOfBytes(using: encoding)
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - 1, length: componentLength + 1)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .parameterString:
            break
        case .query:
            if let queryRange = parseInfo.queryRange {
                let beforeLength = string[..<queryRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[queryRange].lengthOfBytes(using: encoding)
                let afterSeparatorLength = parseInfo.fragmentRange == nil ? 0 : 1
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - 1, length: 1 + componentLength + afterSeparatorLength)
                return CFRange(location: beforeLength, length: componentLength)
            }
        case .fragment:
            if let fragmentRange = parseInfo.fragmentRange {
                let beforeLength = string[..<fragmentRange.lowerBound].lengthOfBytes(using: encoding)
                let componentLength = string[fragmentRange].lengthOfBytes(using: encoding)
                rangeIncludingSeparators.pointee = CFRange(location: beforeLength - 1, length: componentLength + 1)
                return CFRange(location: beforeLength, length: componentLength)
            }
        default:
            break
        }
        return CFRange(location: kCFNotFound, length: 0)
    }

    private func _locationToInsert(component: CFURLComponentType) -> Int {
        let parseInfo = if url.encodedComponents.isEmpty {
            url._parseInfo
        } else {
            RFC3986Parser.rawParse(urlString: url.originalString)
        }
        guard let parseInfo else {
            return 0
        }
        let string = parseInfo.urlString
        let encoding = url._encoding

        var index = string.startIndex
        if component == .scheme {
            return 0
        }
        if let schemeEnd = parseInfo.schemeRange?.upperBound {
            index = string.utf8.index(after: schemeEnd)
        }
        if component == .netLocation {
            let result = string[..<index].lengthOfBytes(using: encoding)
            return parseInfo.netLocationRange == nil ? result : result + 2
        }
        if parseInfo.hasAuthority {
            index = string.utf8.index(index, offsetBy: 2)
        }
        if component == .user || component == .userInfo {
            return string[..<index].lengthOfBytes(using: encoding)
        }
        if let userEnd = parseInfo.userRange?.upperBound {
            index = userEnd
        }
        if component == .password {
            return string[..<index].lengthOfBytes(using: encoding)
        }
        if let passwordEnd = parseInfo.passwordRange?.upperBound {
            index = passwordEnd
        }
        if component == .host {
            return string[..<index].lengthOfBytes(using: encoding)
        }
        if let hostEnd = parseInfo.hostRange?.upperBound {
            index = hostEnd
        }
        if component == .port {
            return string[..<index].lengthOfBytes(using: encoding)
        }
        if let portEnd = parseInfo.portRange?.upperBound {
            index = portEnd
        }
        if component == .path {
            return string[..<index].lengthOfBytes(using: encoding)
        }
        if let pathEnd = parseInfo.pathRange?.upperBound {
            index = pathEnd
        }
        if component == .query || component == .resourceSpecifier {
            return string[..<index].lengthOfBytes(using: encoding)
        }
        if let queryEnd = parseInfo.queryRange?.upperBound {
            index = queryEnd
        }
        if component == .fragment {
            return string[..<index].lengthOfBytes(using: encoding)
        }
        return kCFNotFound
    }

    override func _range(for component: CFURLComponentType, rangeIncludingSeparators: UnsafeMutablePointer<CFRange>) -> CFRange {
        guard isDecomposable else {
            return _nonDecomposableRange(for: component, rangeIncludingSeparators: rangeIncludingSeparators)
        }
        let range = _decomposableRange(for: component, rangeIncludingSeparators: rangeIncludingSeparators)
        if range.location == kCFNotFound {
            rangeIncludingSeparators.pointee = CFRange(location: _locationToInsert(component: component), length: 0)
        }
        return range
    }
}

#endif // FOUNDATION_FRAMEWORK
