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
internal import os

@objc
extension NSURLComponents {
    /// Called from `__NSPlaceholderURLComponents` to create an ObjC `NSURLComponents`
    static func _components() -> _NSSwiftURLComponents? {
        return _NSSwiftURLComponents(components: URLComponents())
    }

    /// Called from `__NSPlaceholderURLComponents` to create an ObjC `NSURLComponents`
    static func _componentsWith(url: URL, resolvingAgainstBaseURL: Bool) -> _NSSwiftURLComponents? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: resolvingAgainstBaseURL) else { return nil }
        return _NSSwiftURLComponents(components: components)
    }

    /// Called from `__NSPlaceholderURLComponents` to create an ObjC `NSURLComponents`
    static func _componentsWith(string: String, encodingInvalidCharacters: Bool) -> _NSSwiftURLComponents? {
        guard let components = URLComponents(string: string, encodingInvalidCharacters: encodingInvalidCharacters) else { return nil }
        return _NSSwiftURLComponents(components: components)
    }

    static func _parseString(_ string: String, encodingInvalidCharacters: Bool, compatibility: URLParserCompatibility.RawValue) -> String? {
        return RFC3986Parser.parse(urlString: string, encodingInvalidCharacters: encodingInvalidCharacters, compatibility: .init(rawValue: compatibility))?.urlString
    }
}

#if canImport(_FoundationICU)
@objc extension NSURLComponents {
    /// Used for the implementation of `_CFURLComponentsMatchURLInString`, allowing us to verify the CF tests run correctly.
    static func _matchWith(string: String, requiredComponents: CFOptionFlags, defaultValues: [Int: String], urlPtr: UnsafeMutablePointer<NSURL?>) -> NSRange {

        func isRequired(_ component: URL.FormatStyle.Component) -> Bool {
            return requiredComponents & UInt(component.rawValue) != 0
        }

        func defaultValue(for component: URL.FormatStyle.Component) -> String? {
            return defaultValues[component.rawValue]
        }

        func parseStrategy(for component: URL.FormatStyle.Component) -> URL.ParseStrategy.ComponentParseStrategy<String> {
            if let value = defaultValue(for: component) {
                return .defaultValue(value)
            } else if isRequired(component) {
                return .required
            } else {
                return .optional
            }
        }

        func parseStrategyForPort() -> URL.ParseStrategy.ComponentParseStrategy<Int> {
            if let portString = defaultValue(for: .port),
               let port = Int(portString) {
                return .defaultValue(port)
            } else if isRequired(.port) {
                return .required
            } else {
                return .optional
            }
        }

        let parseStrategy = URL.ParseStrategy.init(
            scheme: parseStrategy(for: .scheme),
            user: parseStrategy(for: .user),
            password: parseStrategy(for: .password),
            host: parseStrategy(for: .host),
            port: parseStrategyForPort(),
            path: parseStrategy(for: .path),
            query: parseStrategy(for: .query),
            fragment: parseStrategy(for: .fragment)
        )

        var url: URL?
        let range = parseStrategy.matchURL(in: string, url: &url)
        if let url {
            urlPtr.initialize(to: url as NSURL)
        } else {
            urlPtr.initialize(to: nil)
        }
        guard let range else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return string._toRelativeNSRange(range)
    }
}
#endif // canImport(_FoundationICU)

@objc(_NSSwiftURLComponents)
internal class _NSSwiftURLComponents: _NSURLComponentsBridge {
    let lock: OSAllocatedUnfairLock<URLComponents>
    var components: URLComponents {
        lock.withLock { $0 }
    }

    init(components: URLComponents) {
        lock = OSAllocatedUnfairLock(initialState: components)
        super.init()
    }

    override init() {
        lock = OSAllocatedUnfairLock(initialState: URLComponents())
        super.init()
    }

    override init?(string: String) {
        guard let comp = URLComponents(string: string) else {
            return nil
        }
        lock = OSAllocatedUnfairLock(initialState: comp)
        super.init()
    }

    override init?(url: URL, resolvingAgainstBaseURL: Bool) {
        let string: String
        if resolvingAgainstBaseURL {
            string = url.absoluteString
        } else {
            string = url.relativeString
        }
        guard let comp = URLComponents(string: string) else {
            return nil
        }
        lock = OSAllocatedUnfairLock(initialState: comp)
        super.init()
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? _NSSwiftURLComponents {
            return components == other.components
        } else if let other = object as? NSURLComponents {
            return components == other as URLComponents
        } else {
            return false
        }
    }

    override func copy(with zone: NSZone? = nil) -> Any {
        return _NSSwiftURLComponents(components: components)
    }

    override var hash: Int {
        return components.hashValue
    }

    override var description: String {
        return components.description
    }

    override var url: URL? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            guard let string else { return nil }
            return CFURLCreateWithString(kCFAllocatorDefault, string as CFString, nil) as URL?
        }
        #endif
        return components.url
    }

    override func url(relativeTo base: URL?) -> URL? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            guard let string else { return nil }
            return CFURLCreateWithString(kCFAllocatorDefault, string as CFString, base as CFURL?) as URL?
        }
        #endif
        return components.url(relativeTo: base)
    }

    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    override var string: String? {
        return components.string
    }

    override var _scheme: String? {
        components.scheme
    }

    override func _setScheme(_ scheme: String?) -> Bool {
        do {
            try lock.withLock { try $0.setScheme(scheme) }
        } catch {
            return false
        }
        return true
    }

    override var user: String? {
        get { components.user }
        set { lock.withLock { $0.user = newValue } }
    }

    override var password: String? {
        get { components.password }
        set { lock.withLock { $0.password = newValue } }
    }

    override var host: String? {
        get { components.host }
        set { lock.withLock { $0.host = newValue } }
    }

    override var _port: NSNumber? {
        components.port as NSNumber?
    }

    override func _setPort(_ port: NSNumber?) -> Bool {
        do {
            try lock.withLock { try $0.setPort(port?.intValue) }
        } catch {
            return false
        }
        return true
    }

    override var path: String? {
        get { components.path }
        set { lock.withLock { $0.path = newValue ?? "" } }
    }

    override var query: String? {
        get { components.query }
        set { lock.withLock { $0.query = newValue } }
    }

    override var fragment: String? {
        get { components.fragment }
        set { lock.withLock { $0.fragment = newValue } }
    }

    override var _percentEncodedUser: String? {
        components.percentEncodedUser
    }

    override func _setPercentEncodedUser(_ percentEncodedUser: String?) -> Bool {
        do {
            try lock.withLock { try $0.setPercentEncodedUser(percentEncodedUser) }
        } catch {
            return false
        }
        return true
    }

    override var _percentEncodedPassword: String? {
        components.percentEncodedPassword
    }

    override func _setPercentEncodedPassword(_ percentEncodedPassword: String?) -> Bool {
        do {
            try lock.withLock { try $0.setPercentEncodedPassword(percentEncodedPassword) }
        } catch {
            return false
        }
        return true
    }

    override var _percentEncodedHost: String? {
        components.percentEncodedHost
    }

    override func _setPercentEncodedHost(_ percentEncodedHost: String?) -> Bool {
        do {
            try lock.withLock { try $0.setPercentEncodedHost(percentEncodedHost) }
        } catch {
            return false
        }
        return true
    }

    override var _encodedHost: String? {
        components.encodedHost
    }

    override func _setEncodedHost(_ encodedHost: String?) -> Bool {
        do {
            try lock.withLock { try $0.setEncodedHost(encodedHost) }
        } catch {
            return false
        }
        return true
    }

    override var _percentEncodedPath: String {
        components.percentEncodedPath
    }

    override func _setPercentEncodedPath(_ percentEncodedPath: String?) -> Bool {
        do {
            try lock.withLock { try $0.setPercentEncodedPath(percentEncodedPath ?? "") }
        } catch {
            return false
        }
        return true
    }

    override var _percentEncodedQuery: String? {
        components.percentEncodedQuery
    }

    override func _setPercentEncodedQuery(_ percentEncodedQuery: String?) -> Bool {
        do {
            try lock.withLock { try $0.setPercentEncodedQuery(percentEncodedQuery) }
        } catch {
            return false
        }
        return true
    }

    override var _percentEncodedFragment: String? {
        components.percentEncodedFragment
    }

    override func _setPercentEncodedFragment(_ percentEncodedFragment: String?) -> Bool {
        do {
            try lock.withLock { try $0.setPercentEncodedFragment(percentEncodedFragment) }
        } catch {
            return false
        }
        return true
    }

    override var queryItems: [URLQueryItem]? {
        get { components.queryItems }
        set { lock.withLock { $0.queryItems = newValue } }
    }

    override var _percentEncodedQueryItems: [URLQueryItem]? {
        components.percentEncodedQueryItems
    }

    override func _setPercentEncodedQueryItems(_ percentEncodedQueryItems: [URLQueryItem]?) -> Bool {
        do {
            try lock.withLock { try $0.setPercentEncodedQueryItems(percentEncodedQueryItems) }
        } catch {
            return false
        }
        return true
    }

    private func nsStringRange(_ range: Range<String.Index>?) -> NSRange {
        guard let string, let range else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return string._toRelativeNSRange(range)
    }

    override var rangeOfScheme: NSRange {
        nsStringRange(components.rangeOfScheme)
    }

    override var rangeOfUser: NSRange {
        nsStringRange(components.rangeOfUser)
    }

    override var rangeOfPassword: NSRange {
        nsStringRange(components.rangeOfPassword)
    }

    override var rangeOfHost: NSRange {
        nsStringRange(components.rangeOfHost)
    }

    override var rangeOfPort: NSRange {
        nsStringRange(components.rangeOfPort)
    }

    override var rangeOfPath: NSRange {
        nsStringRange(components.rangeOfPath)
    }

    override var rangeOfQuery: NSRange {
        nsStringRange(components.rangeOfQuery)
    }

    override var rangeOfFragment: NSRange {
        nsStringRange(components.rangeOfFragment)
    }
}

@objc
extension NSURLQueryItem {
    /// Called from `__NSURLQueryItem` to create an ObjC `NSURLQueryItem`
    static func _queryItem() -> _NSSwiftURLQueryItem? {
        return _NSSwiftURLQueryItem(queryItem: URLQueryItem(name: "", value: nil))
    }

    /// Called from `__NSURLQueryItem` to create an ObjC `NSURLQueryItem`
    static func _queryItemWith(name: String, value: String?) -> _NSSwiftURLQueryItem? {
        return _NSSwiftURLQueryItem(queryItem: URLQueryItem(name: name, value: value))
    }
}

@objc(_NSSwiftURLQueryItem)
internal final class _NSSwiftURLQueryItem: _NSURLQueryItemBridge, @unchecked Sendable {
    let queryItem: URLQueryItem

    init(queryItem: URLQueryItem) {
        self.queryItem = queryItem
        // This does nothing but we still need to call it.
        super.init(name: queryItem.name, value: queryItem.value)
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? _NSSwiftURLQueryItem {
            return queryItem == other.queryItem
        } else if let other = object as? NSURLQueryItem {
            return queryItem == other as URLQueryItem
        } else {
            return false
        }
    }

    override func copy(with zone: NSZone? = nil) -> Any {
        return _NSSwiftURLQueryItem(queryItem: queryItem)
    }

    override var hash: Int {
        return queryItem.hashValue
    }

    override static var supportsSecureCoding: Bool { true }

    required init?(coder: NSCoder) {
        guard coder.allowsKeyedCoding else {
            coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Cannot be decoded without keyed coding"]))
            return nil
        }

        guard let name = coder.decodeObject(of: NSString.self, forKey: "NS.name") as? String else {
            coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Identifier has been corrupted"]))
            return nil
        }

        let value = coder.decodeObject(of: NSString.self, forKey: "NS.value") as? String

        guard coder.error == nil else {
            return nil
        }

        queryItem = URLQueryItem(name: name, value: value)
        super.init(name: name, value: value)
    }

    override func encode(with coder: NSCoder) {
        // We could implement this in Swift, but for now call up to ObjC superclass.
        super.encode(with: coder)
    }

    override var name: String {
        queryItem.name
    }

    override var value: String? {
        queryItem.value
    }
}

#endif // FOUNDATION_FRAMEWORK
