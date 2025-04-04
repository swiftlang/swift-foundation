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

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
internal import CoreFoundation_Private.CFURL

/// `_BridgedURL` wraps an `NSURL` reference. Its methods use the old implementations, which call directly into `NSURL` methods.
/// `_BridgedURL` is used when an `NSURL` subclass is bridged to Swift, allowing us to:
/// 1) Return the same subclass object when bridging back to ObjC.
/// 2) Call methods that are overridden by the `NSURL` subclass like we did before.
/// - Note: If the `NSURL` subclass does not override a method, `NSURL` will call into the underlying `_SwiftURL` implementation.
internal final class _BridgedURL: _URLProtocol, @unchecked Sendable {
    private let _url: NSURL
    internal init(_ url: NSURL) {
        self._url = url
    }

    init?(string: String) {
        guard !string.isEmpty, let inner = NSURL(string: string) else { return nil }
        _url = inner
    }
    
    init?(string: String, relativeTo url: URL?) {
        guard !string.isEmpty, let inner = NSURL(string: string, relativeTo: url) else { return nil }
        _url = inner
    }
    
    init?(string: String, encodingInvalidCharacters: Bool) {
        guard !string.isEmpty, let inner = NSURL(string: string, encodingInvalidCharacters: encodingInvalidCharacters) else { return nil }
        _url = inner
    }

    init?(stringOrEmpty: String, relativeTo url: URL?) {
        guard let inner = NSURL(string: stringOrEmpty, relativeTo: url) else { return nil }
        _url = inner
    }

    init(fileURLWithPath path: String, isDirectory: Bool, relativeTo base: URL?) {
        _url = NSURL(fileURLWithPath: path.isEmpty ? "." : path, isDirectory: isDirectory, relativeTo: base)
    }
    
    init(fileURLWithPath path: String, relativeTo base: URL?) {
        _url = NSURL(fileURLWithPath: path.isEmpty ? "." : path, relativeTo: base)
    }
    
    init(fileURLWithPath path: String, isDirectory: Bool) {
        _url = NSURL(fileURLWithPath: path.isEmpty ? "." : path, isDirectory: isDirectory)
    }
    
    init(fileURLWithPath path: String) {
        _url = NSURL(fileURLWithPath: path.isEmpty ? "." : path)
    }
    
    init(filePath path: String, directoryHint: URL.DirectoryHint, relativeTo base: URL?) {
        let filePath = path.isEmpty ? "./" : path
        switch directoryHint {
        case .isDirectory:
            _url = NSURL(fileURLWithPath: filePath, isDirectory: true, relativeTo: base)
        case .notDirectory:
            _url = NSURL(fileURLWithPath: filePath, isDirectory: false, relativeTo: base)
        case .checkFileSystem:
            _url = NSURL(fileURLWithPath: filePath, relativeTo: base)
        case .inferFromPath:
            let isDirectory = (filePath.utf8.last == ._slash)
            _url = NSURL(fileURLWithPath: filePath, isDirectory: isDirectory, relativeTo: base)
        }
    }
    
    init?(dataRepresentation: Data, relativeTo base: URL?, isAbsolute: Bool) {
        guard !dataRepresentation.isEmpty else { return nil }
        _url = if isAbsolute {
            NSURL(absoluteURLWithDataRepresentation: dataRepresentation, relativeTo: base)
        } else {
            NSURL(dataRepresentation: dataRepresentation, relativeTo: base)
        }
    }
    
    init(fileURLWithFileSystemRepresentation path: UnsafePointer<Int8>, isDirectory: Bool, relativeTo base: URL?) {
        _url = NSURL(fileURLWithFileSystemRepresentation: path, isDirectory: isDirectory, relativeTo: base)
    }
    
    var dataRepresentation: Data {
        return _url.dataRepresentation
    }

    var relativeString: String {
        return _url.relativeString
    }

    var absoluteString: String {
        // This should never fail for non-file reference URLs
        return _url.absoluteString ?? ""
    }

    var baseURL: URL? {
        return _url.baseURL
    }

    var absoluteURL: URL? {
        // This should never fail for non-file reference URLs
        return _url.absoluteURL
    }

    var scheme: String? {
        return _url.scheme
    }

    var isFileURL: Bool {
        return _url.isFileURL
    }

    var hasAuthority: Bool {
        return user != nil || password != nil || host != nil || port != nil
    }

    var user: String? {
        return _url.user
    }

    func user(percentEncoded: Bool) -> String? {
        let cf = _url._cfurl().takeUnretainedValue()
        if let username = _CFURLCopyUserName(cf, !percentEncoded) {
            return username.takeRetainedValue() as String
        }
        return nil
    }
    
    var password: String? {
        return _url.password
    }

    func password(percentEncoded: Bool) -> String? {
        let cf = _url._cfurl().takeUnretainedValue()
        if let password = _CFURLCopyPassword(cf, !percentEncoded) {
            return password.takeRetainedValue() as String
        }
        return nil
    }
    
    var host: String? {
        return _url.host
    }

    func host(percentEncoded: Bool) -> String? {
        let cf = _url._cfurl().takeUnretainedValue()
        if let host = _CFURLCopyHostName(cf, !percentEncoded) {
            return host.takeRetainedValue() as String
        }
        return nil
    }
    
    var port: Int? {
        return _url.port?.intValue
    }

    var relativePath: String {
        let path = _url.relativePath ?? ""
        if __NSURLSupportDeprecatedParameterComponent(),
           let parameterString = _url._parameterString {
            return path + ";" + parameterString
        }
        return path
    }

    func relativePath(percentEncoded: Bool) -> String {
        let cf = _url._cfurl().takeUnretainedValue()
        if let path = _CFURLCopyPath(cf, !percentEncoded) {
            return path.takeRetainedValue() as String
        }
        return ""
    }

    func absolutePath(percentEncoded: Bool) -> String {
        return absoluteURL?.relativePath(percentEncoded: percentEncoded) ?? relativePath(percentEncoded: percentEncoded)
    }

    var path: String {
        let path = _url.path ?? ""
        if __NSURLSupportDeprecatedParameterComponent(),
           let parameterString = _url._parameterString {
            return path + ";" + parameterString
        }
        return path
    }

    func path(percentEncoded: Bool) -> String {
        if foundation_swift_url_enabled() {
            return absolutePath(percentEncoded: percentEncoded)
        }
        return relativePath(percentEncoded: percentEncoded)
    }
    
    var query: String? {
        return _url.query
    }

    func query(percentEncoded: Bool) -> String? {
        let cf = _url._cfurl().takeUnretainedValue()
        if let queryString = _CFURLCopyQueryString(cf, !percentEncoded) {
            return queryString.takeRetainedValue() as String
        }
        return nil
    }
    
    var fragment: String? {
        return _url.fragment
    }

    func fragment(percentEncoded: Bool) -> String? {
        let cf = _url._cfurl().takeUnretainedValue()
        if let fragment = _CFURLCopyFragment(cf, !percentEncoded) {
            return fragment.takeRetainedValue() as String
        }
        return nil
    }

    func fileSystemPath(style: URL.PathStyle, resolveAgainstBase: Bool, compatibility: Bool) -> String {
        let path = resolveAgainstBase ? absolutePath(percentEncoded: true) : relativePath(percentEncoded: true)
        return _SwiftURL.fileSystemPath(for: path, style: style, compatibility: compatibility)
    }

    func withUnsafeFileSystemRepresentation<ResultType>(_ block: (UnsafePointer<Int8>?) throws -> ResultType) rethrows -> ResultType {
        return try block(_url.fileSystemRepresentation)
    }
    
    var hasDirectoryPath: Bool {
        return _url.hasDirectoryPath
    }

    var pathComponents: [String] {
        return _url.pathComponents ?? []
    }

    var lastPathComponent: String {
        return _url.lastPathComponent ?? ""
    }

    var pathExtension: String {
        return _url.pathExtension ?? ""
    }

    func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL? {
        if let result = _url.appendingPathComponent(pathComponent, isDirectory: isDirectory) {
            return result
        }
        guard var c = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        let path = (c.path as NSString).appendingPathComponent(pathComponent)
        c.path = isDirectory ? path + "/" : path
        return c.url
    }
    
    func appendingPathComponent(_ pathComponent: String) -> URL? {
        if let result = _url.appendingPathComponent(pathComponent) {
            return result
        }
        guard var c = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        c.path = (c.path as NSString).appendingPathComponent(pathComponent)
        return c.url
    }
    
    func deletingLastPathComponent() -> URL? {
        guard !path.isEmpty else { return nil }
        return _url.deletingLastPathComponent
    }
    
    func appendingPathExtension(_ pathExtension: String) -> URL? {
        guard !path.isEmpty else { return nil }
        return _url.appendingPathExtension(pathExtension)
    }
    
    func deletingPathExtension() -> URL? {
        guard !path.isEmpty else { return nil }
        return _url.deletingPathExtension
    }
    
    func appending<S>(path: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        let path = String(path)
        let hasTrailingSlash = (path.utf8.last == ._slash)
        let isDirectory: Bool?
        switch directoryHint {
        case .isDirectory:
            isDirectory = true
        case .notDirectory:
            isDirectory = false
        case .checkFileSystem:
            if self.isFileURL {
                // We can only check file system if the URL is a file URL
                isDirectory = nil
            } else {
                // For web addresses, trust the caller's trailing slash
                isDirectory = hasTrailingSlash
            }
        case .inferFromPath:
            isDirectory = hasTrailingSlash
        }

        let result = if let isDirectory {
            _url.appendingPathComponent(path, isDirectory: isDirectory)
        } else {
            // This method consults the file system
            _url.appendingPathComponent(path)
        }

        if let result {
            return result
        }

        guard var c = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        var newPath = (c.path as NSString).appendingPathComponent(path)
        if let isDirectory, isDirectory, newPath.utf8.last != ._slash {
            newPath += "/"
        }
        c.path = newPath
        return c.url
    }
    
    func appending<S>(component: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        let pathComponent = String(component)
        let hasTrailingSlash = (pathComponent.utf8.last == ._slash)
        let isDirectory: Bool?
        switch directoryHint {
        case .isDirectory:
            isDirectory = true
        case .notDirectory:
            isDirectory = false
        case .checkFileSystem:
            if self.isFileURL {
                // We can only check file system if the URL is a file URL
                isDirectory = nil
            } else {
                // For web addresses, trust the caller's trailing slash
                isDirectory = hasTrailingSlash
            }
        case .inferFromPath:
            isDirectory = hasTrailingSlash
        }

        let cf = _url._cfurl().takeUnretainedValue()
        if let isDirectory {
            return _CFURLCreateCopyAppendingPathComponent(cf, pathComponent as CFString, isDirectory).takeRetainedValue() as URL
        }

        #if !NO_FILESYSTEM
        // Create a new URL without the trailing slash
        let url = self.appending(component: component, directoryHint: .notDirectory) ?? URL(self)
        // See if it refers to a directory
        if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
           let isDirectoryValue = resourceValues.isDirectory {
            return _CFURLCreateCopyAppendingPathComponent(cf, pathComponent as CFString, isDirectoryValue).takeRetainedValue() as URL
        }
        #endif

        // Fall back to inferring from the trailing slash
        return _CFURLCreateCopyAppendingPathComponent(cf, pathComponent as CFString, hasTrailingSlash).takeRetainedValue() as URL
    }
    
    var standardized: URL? {
        return _url.standardized
    }

#if !NO_FILESYSTEM
    var standardizedFileURL: URL? {
        return _url.standardizingPath
    }

    func resolvingSymlinksInPath() -> URL? {
        return _url.resolvingSymlinksInPath
    }
#endif

    var description: String {
        return _url.description
    }

    var debugDescription: String {
        return _url.debugDescription
    }

    func bridgeToNSURL() -> NSURL {
        return _url
    }

    func isFileReferenceURL() -> Bool {
        #if NO_FILESYSTEM
        return false
        #else
        return _url.isFileReferenceURL()
        #endif
    }

    func convertingFileReference() -> any _URLProtocol & AnyObject {
        #if NO_FILESYSTEM
        return self
        #else
        guard _url.isFileReferenceURL() else { return self }
        if let url = _url.filePathURL {
            return Self.init(url as NSURL)
        }
        return Self.init(string: "com-apple-unresolvable-file-reference-url:")!
        #endif
    }
}


/// `_BridgedNSSwiftURL` wraps an `_NSSwiftURL`, which is the Swift subclass of `NSURL`.
/// `_BridgedNSSwiftURL` is used when an `_NSSwiftURL` is bridged to Swift, allowing us to
/// return the same object (pointer) when bridging back to ObjC, such as in cases where `.absoluteURL`
/// should return `self`, or `.baseURL` should return a pointer to the same `NSURL` from initialization.
/// At the same time, this allows us to use the new `_SwiftURL` for `NSURL`s bridged to Swift.
internal final class _BridgedNSSwiftURL: _URLProtocol, @unchecked Sendable {
    private let _wrapped: _NSSwiftURL
    internal init(_ url: _NSSwiftURL) {
        _wrapped = url
    }

    private var _url: _SwiftURL {
        return _wrapped.url
    }

    init?(string: String) {
        guard !string.isEmpty, let inner = _SwiftURL(string: string) else { return nil }
        _wrapped = _NSSwiftURL(url: inner)
    }

    init?(string: String, relativeTo url: URL?) {
        guard !string.isEmpty, let inner = _SwiftURL(string: string, relativeTo: url) else { return nil }
        _wrapped = _NSSwiftURL(url: inner)
    }

    init?(string: String, encodingInvalidCharacters: Bool) {
        guard !string.isEmpty, let inner = _SwiftURL(string: string, encodingInvalidCharacters: encodingInvalidCharacters) else { return nil }
        _wrapped = _NSSwiftURL(url: inner)
    }

    init?(stringOrEmpty: String, relativeTo url: URL?) {
        guard let inner = _SwiftURL(string: stringOrEmpty, relativeTo: url) else { return nil }
        _wrapped = _NSSwiftURL(url: inner)
    }

    init(fileURLWithPath path: String, isDirectory: Bool, relativeTo base: URL?) {
        let inner = _SwiftURL(fileURLWithPath: path.isEmpty ? "." : path, isDirectory: isDirectory, relativeTo: base)
        _wrapped = _NSSwiftURL(url: inner)
    }

    init(fileURLWithPath path: String, relativeTo base: URL?) {
        let inner = _SwiftURL(fileURLWithPath: path.isEmpty ? "." : path, relativeTo: base)
        _wrapped = _NSSwiftURL(url: inner)
    }

    init(fileURLWithPath path: String, isDirectory: Bool) {
        let inner = _SwiftURL(fileURLWithPath: path.isEmpty ? "." : path, isDirectory: isDirectory)
        _wrapped = _NSSwiftURL(url: inner)
    }

    init(fileURLWithPath path: String) {
        let inner = _SwiftURL(fileURLWithPath: path.isEmpty ? "." : path)
        _wrapped = _NSSwiftURL(url: inner)
    }

    init(filePath path: String, directoryHint: URL.DirectoryHint, relativeTo base: URL?) {
        let filePath = path.isEmpty ? "./" : path
        let inner = switch directoryHint {
        case .isDirectory:
            _SwiftURL(fileURLWithPath: filePath, isDirectory: true, relativeTo: base)
        case .notDirectory:
            _SwiftURL(fileURLWithPath: filePath, isDirectory: false, relativeTo: base)
        case .checkFileSystem:
            _SwiftURL(fileURLWithPath: filePath, relativeTo: base)
        case .inferFromPath:
            _SwiftURL(fileURLWithPath: filePath, isDirectory: (filePath.utf8.last == ._slash), relativeTo: base)
        }
        _wrapped = _NSSwiftURL(url: inner)
    }

    init?(dataRepresentation: Data, relativeTo base: URL?, isAbsolute: Bool) {
        guard !dataRepresentation.isEmpty,
              let inner = _SwiftURL(dataRepresentation: dataRepresentation, relativeTo: base, isAbsolute: isAbsolute) else {
            return nil
        }
        _wrapped = _NSSwiftURL(url: inner)
    }

    init(fileURLWithFileSystemRepresentation path: UnsafePointer<Int8>, isDirectory: Bool, relativeTo base: URL?) {
        let inner = _SwiftURL(fileURLWithFileSystemRepresentation: path, isDirectory: isDirectory, relativeTo: base)
        _wrapped = _NSSwiftURL(url: inner)
    }

    var dataRepresentation: Data {
        return _url.dataRepresentation
    }

    var relativeString: String {
        return _url.relativeString
    }

    var absoluteString: String {
        // This should never fail for non-file reference URLs
        return _url.absoluteString
    }

    var baseURL: URL? {
        return _url.baseURL
    }

    var absoluteURL: URL? {
        // This should never fail for non-file reference URLs
        return _url.absoluteURL
    }

    var scheme: String? {
        return _url.scheme
    }

    var isFileURL: Bool {
        return _url.isFileURL
    }

    var hasAuthority: Bool {
        return user != nil || password != nil || host != nil || port != nil
    }

    var user: String? {
        return _url.user
    }

    func user(percentEncoded: Bool) -> String? {
        return _url.user(percentEncoded: percentEncoded)
    }

    var password: String? {
        return _url.password
    }

    func password(percentEncoded: Bool) -> String? {
        return _url.password(percentEncoded: percentEncoded)
    }

    var host: String? {
        return _url.host
    }

    func host(percentEncoded: Bool) -> String? {
        return _url.host(percentEncoded: percentEncoded)
    }

    var port: Int? {
        return _url.port
    }

    var relativePath: String {
        return _url.relativePath
    }

    func relativePath(percentEncoded: Bool) -> String {
        return _url.relativePath(percentEncoded: percentEncoded)
    }

    func absolutePath(percentEncoded: Bool) -> String {
        return _url.absolutePath(percentEncoded: percentEncoded)
    }

    var path: String {
        return _url.path
    }

    func path(percentEncoded: Bool) -> String {
        return absolutePath(percentEncoded: percentEncoded)
    }

    var query: String? {
        return _url.query
    }

    func query(percentEncoded: Bool) -> String? {
        return _url.query(percentEncoded: percentEncoded)
    }

    var fragment: String? {
        return _url.fragment
    }

    func fragment(percentEncoded: Bool) -> String? {
        return _url.fragment(percentEncoded: percentEncoded)
    }

    func fileSystemPath(style: URL.PathStyle, resolveAgainstBase: Bool, compatibility: Bool) -> String {
        return _url.fileSystemPath(style: style, resolveAgainstBase: resolveAgainstBase, compatibility: compatibility)
    }

    func withUnsafeFileSystemRepresentation<ResultType>(_ block: (UnsafePointer<Int8>?) throws -> ResultType) rethrows -> ResultType {
        return try _url.withUnsafeFileSystemRepresentation(block)
    }

    var hasDirectoryPath: Bool {
        return _url.hasDirectoryPath
    }

    var pathComponents: [String] {
        return _url.pathComponents
    }

    var lastPathComponent: String {
        return _url.lastPathComponent
    }

    var pathExtension: String {
        return _url.pathExtension
    }

    func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL? {
        return _url.appendingPathComponent(pathComponent, isDirectory: isDirectory)
    }

    func appendingPathComponent(_ pathComponent: String) -> URL? {
        return _url.appendingPathComponent(pathComponent)
    }

    func deletingLastPathComponent() -> URL? {
        return _url.deletingLastPathComponent()
    }

    func appendingPathExtension(_ pathExtension: String) -> URL? {
        return _url.appendingPathExtension(pathExtension)
    }

    func deletingPathExtension() -> URL? {
        return _url.deletingPathExtension()
    }

    func appending<S>(path: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        return _url.appending(path: path, directoryHint: directoryHint)
    }

    func appending<S>(component: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        return _url.appending(component: component, directoryHint: directoryHint)
    }

    var standardized: URL? {
        return _url.standardized
    }

#if !NO_FILESYSTEM
    var standardizedFileURL: URL? {
        return _url.standardizedFileURL
    }

    func resolvingSymlinksInPath() -> URL? {
        return _url.resolvingSymlinksInPath()
    }
#endif

    var description: String {
        return _url.description
    }

    var debugDescription: String {
        return _url.debugDescription
    }

    func bridgeToNSURL() -> NSURL {
        return _wrapped
    }

    func isFileReferenceURL() -> Bool {
        #if NO_FILESYSTEM
        return false
        #else
        return _url.isFileReferenceURL()
        #endif
    }

    func convertingFileReference() -> any _URLProtocol & AnyObject {
        #if NO_FILESYSTEM
        return self
        #else
        guard _url.isFileReferenceURL() else { return self }
        if let url = _wrapped.filePathURL {
            return url._url
        }
        return _SwiftURL(string: "com-apple-unresolvable-file-reference-url:")!
        #endif
    }
}

#endif
