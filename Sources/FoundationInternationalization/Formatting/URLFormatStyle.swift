//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension URL {
    /// A structure that converts between URL instances and their textual representations.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public struct FormatStyle: Codable, Hashable, Sendable {
        /// The strategy to display the `scheme` component.
        var scheme: ComponentDisplayOption
        /// The strategy to display the `user` component.
        var user: ComponentDisplayOption
        /// The strategy to display the `password` component.
        var password: ComponentDisplayOption
        /// The strategy to display the `host` component.
        var host: HostDisplayOption
        /// The strategy to display the `port` component.
        var port: ComponentDisplayOption
        /// The strategy to display the `path` component.
        var path: ComponentDisplayOption
        /// The strategy to display the `query` component.
        var query: ComponentDisplayOption
        /// The strategy to display the `fragment` component.
        var fragment: ComponentDisplayOption

        /// Creates a new `FormatStyle` with the given configurations.
        /// - Parameters:
        ///   - scheme: The strategy to use for formatting the `scheme`.
        ///   - user: The strategy to use for formatting the `user`.
        ///   - password: The strategy to use for formatting the `password`.
        ///   - host: The strategy to use for formatting the `host`.
        ///   - port: The strategy to use for formatting the `port`.
        ///   - path: The strategy to use for formatting the `path`.
        ///   - query: The strategy to use for formatting the `query`.
        ///   - fragment: The strategy to use for formatting the `fragment`.
        public init(
            scheme: ComponentDisplayOption = .always,
            user: ComponentDisplayOption = .never,
            password: ComponentDisplayOption = .never,
            host: HostDisplayOption = .always,
            port: ComponentDisplayOption = .omitIfHTTPFamily,
            path: ComponentDisplayOption = .always,
            query: ComponentDisplayOption = .never,
            fragment: ComponentDisplayOption = .never
        ) {
            self.scheme = scheme
            self.user = user
            self.password = password
            self.host = host
            self.port = port
            self.path = path
            self.query = query
            self.fragment = fragment
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.FormatStyle {
    /// An enumeration of the components of a URL, for use in creating format style options that depend on a component's value.
    ///
    /// You use this type with style-modifying methods like ``URL/FormatStyle/ComponentDisplayOption/displayWhen(_:matches:)`` in ``URL/FormatStyle/ComponentDisplayOption`` and ``URL/FormatStyle/HostDisplayOption/omitWhen(_:matches:)`` in ``URL/FormatStyle/HostDisplayOption``.
    public enum Component: Int, Codable, Hashable, Sendable, CustomStringConvertible {
        // These raw values MUST match _CFURLRequiredComponents
        /// The URL format style scheme component.
        case scheme = 0b00000001 // 1 << 0
        /// The URL format style user component.
        case user = 0b00000010 // 1 << 1
        /// The URL format style password component.
        case password = 0b00000100 // 1 << 2
        /// The URL format style host component.
        case host = 0b00001000 // 1 << 3
        /// The URL format style port component.
        case port = 0b00010000 // 1 << 4
        /// The URL format style path component.
        case path = 0b00100000 // 1 << 5
        /// The URL format style query component.
        case query = 0b01000000 // 1 << 6
        /// The URL format style fragment component.
        case fragment = 0b10000000 // 1 << 7

        public var description: String {
            switch self {
            case .scheme: return "scheme"
            case .user: return "username"
            case .password: return "password"
            case .host: return "host"
            case .port: return "port"
            case .path: return "path"
            case .query: return "query"
            case .fragment: return "fragment"
            }
        }

        internal func getComponentValue<T>(from url: URL) -> T? {
            switch self {
            case .scheme: return url.scheme as? T
            case .user: return url.user as? T
            case .password: return url.password as? T
            case .host: return url.host as? T
            case .port: return url.port as? T
            case .path: return url.path as? T
            case .query: return url.query as? T
            case .fragment: return url.fragment as? T
            }
        }

        internal func hasComponentValue(in url: URL) -> Bool {
            switch self {
            case .scheme: return url.scheme != nil
            case .user: return url.user != nil
            case .password: return url.password != nil
            case .host: return url.host != nil
            case .port: return url.port != nil
            case .path: return !url.path.isEmpty
            case .query: return url.query != nil
            case .fragment: return url.fragment != nil
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.FormatStyle {
    /// Specifies the condition to display a component
    internal struct ComponentDisplayCondition: Codable, Hashable, CustomStringConvertible, Sendable {
        let component: URL.FormatStyle.Component
        let requirements: Set<String>

        var description: String {
            return "if \(component) matches \(requirements)"
        }
    }

    /// Specifies the display option for a component, including whether to display or omit the
    /// component and the condition to do so.
    public struct ComponentDisplayOption: Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option: Int, Codable, Hashable {
            case omitted
            case displayed
        }

        var option: Option
        var condition: ComponentDisplayCondition?

        public var description: String {
            switch self.option {
            case .omitted:
                if let condition = condition {
                    return "omitted(condition: \(condition))"
                }
                return "never"
            case .displayed:
                if let condition = condition {
                    return "displayed(condition: \(condition))"
                }
                return "always"
            }
        }

        /// Creates a display option to always display the component.
        public static var always: Self {
            .init(option: .displayed, condition: nil)
        }

        /// Creates a display option to always omit the component.
        public static var never: Self {
            .init(option: .omitted, condition: nil)
        }

        /// Creates a display option to display the component if the given condition is met.
        public static func displayWhen(_ component: URL.FormatStyle.Component, matches requirements: Set<String>) -> Self {
            .init(option: .displayed, condition: .init(component: component, requirements: requirements))
        }

        /// Creates a display option to omit the component if the given condition is met.
        public static func omitWhen(_ component: URL.FormatStyle.Component, matches requirements: Set<String>) -> Self {
            .init(option: .omitted, condition: .init(component: component, requirements: requirements))
        }

        /// Creates a display option to omit the component if the URL's scheme
        /// is `http` or `https`.
        public static var omitIfHTTPFamily: Self {
            .init(option: .omitted, condition: .init(component: .scheme, requirements: ["http", "https"]))
        }
    }

    /// Specifies the display option for displaying the host component
    public struct HostDisplayOption: Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option: Codable, Hashable, Sendable {
            case omitted
            case displayed

            private typealias OmittedCodingKeys = EmptyCodingKeys
            private typealias DisplayedCodingKeys = EmptyCodingKeys
        }

        var option: Option
        var condition: ComponentDisplayCondition?
        /// Whether deep (more than three) subdomains should be omitted
        /// For example: `api.docs.code.example.com` will be
        /// shorten to `code.example.com`
        var omitMultiLevelSubdomains: Bool
        /// A set of specific subdomains to omit.
        var omitSpecificSubdomains: Set<String>?

        public var description: String {
            switch self.option {
            case .omitted:
                if let condition = condition {
                    return "omitted(condition: \(condition))"
                }
                return "never"
            case .displayed:
                var conditionString = "no condition"
                if let condition = condition {
                    conditionString = String(describing: condition)
                }
                return "displayed(omitMultiLevelSubdomains: \(self.omitMultiLevelSubdomains), omitSpecificSubdomains: \(self.omitSpecificSubdomains ?? Set()), condition: \(conditionString)"
            }
        }

        private init(option: Option, condition: ComponentDisplayCondition?, omitMultiLevelSubdomains: Bool = false, omitSpecificSubdomains: Set<String>? = nil) {
            self.option = option
            self.condition = condition
            self.omitMultiLevelSubdomains = omitMultiLevelSubdomains
            self.omitSpecificSubdomains = omitSpecificSubdomains
        }

        /// Creates a display option to always display the host.
        public static var always: Self {
            .init(option: .displayed, condition: nil)
        }

        /// Creates a display option to always omit the host.
        public static var never: Self {
            .init(option: .omitted, condition: nil)
        }

        /// Creates a display option to display the host if the given condition is met.
        public static func displayWhen(_ component: URL.FormatStyle.Component, matches requirements: Set<String>) -> Self {
            .init(option: .displayed, condition: .init(component: component, requirements: requirements))
        }

        /// Creates a display option to omit the host if the given condition is met.
        public static func omitWhen(_ component: URL.FormatStyle.Component, matches requirements: Set<String>) -> Self {
            .init(option: .omitted, condition: .init(component: component, requirements: requirements))
        }

        /// Creates a display option to omit the host if the URL's scheme
        /// is `http` or `https`.
        public static var omitIfHTTPFamily: Self {
            .init(option: .omitted, condition: .init(component: .scheme, requirements: ["http", "https"]))
        }

        /// Creates a display option to manipulate the subdomains of a host
        /// - Parameters:
        ///   - subdomainsToOmit: specifies a set of subdomains to omit
        ///   - omitMultiLevelSubdomains: if `true`, multi-level subdomains
        ///     (more than two subdomains beyond the TLDs)  will be omitted.
        public static func omitSpecificSubdomains(
            _ subdomainsToOmit: Set<String> = Set(),
            includeMultiLevelSubdomains omitMultiLevelSubdomains: Bool = false
        ) -> Self {
            .init(option: .displayed, condition: nil, omitMultiLevelSubdomains: omitMultiLevelSubdomains, omitSpecificSubdomains: subdomainsToOmit)
        }

        /// Creates a display option to manipulate the subdomains of a host
        /// - Parameters:
        ///   - subdomainsToOmit: specifies a set of subdomains to omit
        ///   - omitMultiLevelSubdomains: if `true`, multi-level subdomains
        ///     (more than two subdomains beyond the TLDs)  will be omitted.
        ///   - component: the component to test for condition.
        ///   - requirements: the requirements for the component.
        public static func omitSpecificSubdomains(
            _ subdomainsToOmit: Set<String> = Set(),
            includeMultiLevelSubdomains omitMultiLevelSubdomains: Bool = false,
            when component: URL.FormatStyle.Component, matches requirements: Set<String>
        ) -> Self {
            .init(
                option: .displayed,
                condition: .init(component: component, requirements: requirements),
                omitMultiLevelSubdomains: omitMultiLevelSubdomains,
                omitSpecificSubdomains: subdomainsToOmit)
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.FormatStyle {
    /// Modifies a format style to display a URL's scheme component in accordance with the provided option.
    ///
    /// - Parameter strategy: A component display option that indicates when, if ever, to display the scheme.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func scheme(_ strategy: ComponentDisplayOption = .always) -> Self {
        var new = self
        new.scheme = strategy
        return new
    }

    /// Modifies a format style to display a URL's user component in accordance with the provided option.
    ///
    /// - Parameter strategy: A component display option that indicates when, if ever, to display the user component.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func user(_ strategy: ComponentDisplayOption = .never) -> Self {
        var new = self
        new.user = strategy
        return new
    }

    /// Modifies a format style to display a URL's password component in accordance with the provided option.
    ///
    /// - Parameter strategy: A component display option that indicates when, if ever, to display the password component.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func password(_ strategy: ComponentDisplayOption = .never) -> Self {
        var new = self
        new.password = strategy
        return new
    }

    /// Modifies a format style to display a URL's host component in accordance with the provided option.
    ///
    /// - Parameter strategy: A host display option that indicates when, if ever, to display the host component.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func host(_ strategy: HostDisplayOption = .always) -> Self {
        var new = self
        new.host = strategy
        return new
    }

    /// Modifies a format style to display a URL's port component in accordance with the provided option.
    ///
    /// - Parameter strategy: A component display option that indicates when, if ever, to display the port component.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func port(_ strategy: ComponentDisplayOption = .omitIfHTTPFamily) -> Self {
        var new = self
        new.port = strategy
        return new
    }

    /// Modifies a format style to display a URL's path component in accordance with the provided option.
    ///
    /// - Parameter strategy: A component display option that indicates when, if ever, to display the path component.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func path(_ strategy: ComponentDisplayOption = .always) -> Self {
        var new = self
        new.path = strategy
        return new
    }

    /// Modifies a format style to display a URL's query component in accordance with the provided option.
    ///
    /// - Parameter strategy: A component display option that indicates when, if ever, to display the query component.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func query(_ strategy: ComponentDisplayOption = .never) -> Self {
        var new = self
        new.query = strategy
        return new
    }

    /// Modifies a format style to display a URL's fragment component in accordance with the provided option.
    ///
    /// - Parameter strategy: A component display option that indicates when, if ever, to display the fragment component.
    /// - Returns: A modified ``URL/FormatStyle`` that incorporates the specified behavior.
    public func fragment(_ strategy: ComponentDisplayOption = .never) -> Self {
        var new = self
        new.fragment = strategy
        return new
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.FormatStyle: ParseableFormatStyle {
    /// The parse strategy used by this format style.
    public var parseStrategy: URL.ParseStrategy {
        .init(format: self, lenient: false)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.FormatStyle: FormatStyle {
    @inline(__always)
    private func url(_ url: URL, satisfies condition: ComponentDisplayCondition?) -> Bool {
        guard let condition = condition else {
            return true
        }
        if condition.component == .port {
            guard let port: Int = condition.component.getComponentValue(from: url) else {
                return false
            }
            return condition.requirements.contains(String(port))
        }
        guard let value: String = condition.component.getComponentValue(from: url) else {
            return false
        }
        return condition.requirements.contains(value)
    }

    @inline(__always)
    private func shouldDisplayComponent(from url: URL, basedOn strategy: ComponentDisplayOption) -> Bool {
        let componentSatisfiesCondition = self.url(url, satisfies: strategy.condition)
        return (componentSatisfiesCondition && strategy.option == .displayed) || (!componentSatisfiesCondition && strategy.option == .omitted)
    }

    @inline(__always)
    private func exists(_ value: String?) -> Bool {
        guard let value = value else {
            return false
        }
        return !value.isEmpty
    }

    private func isIPv4(_ hostString: String) -> Bool {
        let components = hostString.split(separator: ".")
        guard components.count == 4 else {
            return false
        }
        for component in components {
            guard let intValue = Int(component), intValue >= 0 && intValue < 256 else {
                return false
            }
        }
        return true
    }

    private func isIPv6(_ hostString: String) -> Bool {
        var host = hostString
        // IPv6 addresses must be enclosed with `[]` as part of the URL
        guard host.hasPrefix("[") && host.hasSuffix("]") else {
            return false
        }
        // Remove the brackets for parsing
        host.removeFirst()
        host.removeLast()

        // Since IPv6 can be shortened to arbitrary groups, we won't check
        // how many groups are there; instead, we will check each group is
        // either empty or a valid hex string
        let groups = host.split(separator: ":")
        for group in groups {
            guard !group.isEmpty else {
                // It's okay to have empty groups such as `::1`
                continue
            }
            guard let intValue = Int(String(group), radix: 16),
                intValue >= 0, intValue <= 0xFFFF
            else {
                return false
            }
        }
        return true
    }

    private func generateFormattedString(from urlComponents: URLComponents, useEncodedHost: Bool) -> String {
        // We can't use urlComponents.string directly because URLComponents uses encoded
        // components (rightfully so) to compute the string. For a user-facing formatted
        // string, we should use all raw components instead
        var urlString = ""
        // Append scheme
        if let scheme = urlComponents.scheme {
            urlString.append("\(scheme):")
            // Append "//" if there's a host
            if urlComponents.host != nil {
                urlString.append("//")
            }
        }
        // Append user
        if let user = urlComponents.user {
            urlString.append(user)
        }
        // Append password
        if let password = urlComponents.password {
            if urlComponents.user != nil {
                // Append `:` between user and password
                urlString.append(":")
            }
            urlString.append(password)
        }
        // Append host
        let hostString = useEncodedHost ? urlComponents.encodedHost : urlComponents.host
        if let host = hostString {
            if urlComponents.user != nil || urlComponents.password != nil {
                // Append `@` between authority and host
                urlString.append("@")
            }
            urlString.append(host)
        }
        // Append port
        if let port = urlComponents.port {
            if urlComponents.host != nil {
                // Append `:` between host and port
                urlString.append(":")
            }
            urlString.append("\(port)")
        }
        // Append path
        if !urlComponents.path.isEmpty {
            // Remove the path trailing slash if path
            // is the last component displayed
            var path = urlComponents.path
            if path.hasSuffix("/") && urlComponents.query == nil && urlComponents.fragment == nil {
                path.removeLast()
            }
            urlString.append(path)
        }
        // Append query
        if let query = urlComponents.query {
            urlString.append("?\(query)")
        }
        // Append fragment
        if let fragment = urlComponents.fragment {
            urlString.append("#\(fragment)")
        }

        return urlString
    }

    private func formatMultiLevelSubdomains(from subdomains: inout [Substring], forHost hostString: String) {
        // Remove all "extra" subdomains from a host beyond TLDs + 2 subdomains
        // For example:
        // developer.source.apple.com -> source.apple.com (TLD: com)
        // developer.source.apple.com.cn -> source.apple.com.cn (TLD: com.cn)
        #if FOUNDATION_FRAMEWORK
        guard let tlds = __NSURLGetTopLevelDomain(hostString, true) else {
            // If the host string does not contain a valid TLD, do nothing
            return
        }
        let numberOfTLDs = tlds.split(separator: ".").count
        guard subdomains.count > numberOfTLDs + 2 else {
            // Nothing to do. The hostString does not have any extra subdomains
            return
        }
        subdomains.removeFirst(subdomains.count - (numberOfTLDs + 2))
        #endif
    }

    /// Formats a URL, using this style.
    ///
    /// Use this method when you want to create a single style instance, and then
    /// use it to format multiple URL instances. The following example creates a
    /// custom format style and then uses it to format a variety of URLs in an array:
    ///
    /// ```swift
    /// let style = URL.FormatStyle(
    ///     scheme: .never,
    ///     user: .never,
    ///     password: .never,
    ///     host: .omitSpecificSubdomains(["www", "mobile", "m."],
    ///                                   includeMultiLevelSubdomains: true),
    ///     port: .never,
    ///     path: .always,
    ///     query: .never,
    ///     fragment: .never)
    /// let urls = [
    ///     URL(string: "https://www.example.com/path/one")!,
    ///     URL(string: "https://beta.example.com/path/two")!,
    ///     URL(string: "https://beta.staging.west.example.com/three")!,
    ///     URL(string: "https://query.example.com/four?key4=value4")!
    /// ]
    /// let formatted = urls.map { $0.formatted(style) }
    /// // ["example.com/path/one", "beta.example.com/path/two", "west.example.com/three", "query.example.com/four"]
    /// ```
    ///
    /// To format a single URL value, use the ``URL`` instance method
    /// ``URL/formatted(_:)`` passing in an instance of ``URL/FormatStyle``,
    /// or ``URL/formatted()`` to use a default style.
    ///
    /// - Parameter value: The URL to format.
    /// - Returns: A string representation of `value`, formatted according to the style's configuration.
    public func format(_ value: URL) -> String {
        // URL(NSURL)'s old parser doesn't play well with Unicode
        // characters. Use an `URLComponents` (which has the updated
        // parser) to access all the decoded components instead of
        // accessing them via URL directly
        guard
            let decoder = URLComponents(
                url: value, resolvingAgainstBaseURL: false)
        else {
            return value.absoluteString
        }
        var urlComponents = URLComponents()
        // Format scheme
        if shouldDisplayComponent(from: value, basedOn: scheme) {
            urlComponents.scheme = decoder.scheme
        }
        // Format user
        if shouldDisplayComponent(from: value, basedOn: user) {
            urlComponents.user = decoder.user
        }
        // Format password
        if shouldDisplayComponent(from: value, basedOn: password) {
            urlComponents.password = decoder.password
        }
        // Format host
        var hostContainsLookalikeCharacters = false
        if let hostString = decoder.host, !hostString.isEmpty {
            let hostSatisfiesCondition = self.url(value, satisfies: self.host.condition)
            // Determine whether the host is an IP address:
            // - For ipv6, we need to add an additional `[]` around the host
            // - For both ipv6 and ipv4, we shouldn't modify the host in anyway
            let isIPv4 = self.isIPv4(hostString)
            let isIPv6 = self.isIPv6(hostString)
            let isIPAddress = isIPv4 || isIPv6
            // Determine if the hostString contains lookalike characters.
            // If the host contains lookalike characters, use the Punycode
            // encoded host instead
            hostContainsLookalikeCharacters = URL.UnicodeLookalikeTable.default.shouldDisplayEncodedHost(for: hostString)

            switch self.host.option {
            case .displayed:
                var componentsModified = false
                var formattedHost: String? = nil
                if hostContainsLookalikeCharacters {
                    // If the host contains lookalike characters, use the raw,
                    // unprocessed hostString instead. `URLComponents` will
                    // automatically encode the host
                    formattedHost = hostString
                } else {
                    var hostComponents = hostString.split(separator: ".")
                    // Format each subdomains
                    if self.host.omitMultiLevelSubdomains && hostComponents.count > 3 && !isIPAddress {
                        self.formatMultiLevelSubdomains(from: &hostComponents, forHost: hostString)
                        componentsModified = true
                    }
                    if let subdomainsToOmit = self.host.omitSpecificSubdomains,
                        hostComponents.count > 2,
                        !isIPAddress,
                        subdomainsToOmit.contains(String(hostComponents[0]))
                    {
                        // Remove the first subdomain if it's one of the subdomainsToOmit
                        hostComponents.removeFirst()
                        componentsModified = true
                    }
                    // Prepare `formattedHost`
                    if isIPAddress {
                        // Don't modify IP address
                        formattedHost = hostString
                    } else {
                        formattedHost = hostComponents.joined(separator: ".")
                    }
                }

                if hostSatisfiesCondition {
                    urlComponents.host = formattedHost
                } else if componentsModified {
                    // If the host does not satisfy the condition, do not
                    // omit subdomains
                    urlComponents.host = hostString
                }
            case .omitted:
                if !hostSatisfiesCondition {
                    urlComponents.host = hostString
                }
            }
        }
        // Format port
        if shouldDisplayComponent(from: value, basedOn: port) {
            urlComponents.port = decoder.port
        }
        // Format path
        if shouldDisplayComponent(from: value, basedOn: path) {
            urlComponents.path = decoder.path
        }
        // Format query
        if shouldDisplayComponent(from: value, basedOn: query) {
            urlComponents.query = decoder.query
        }
        // Format fragment
        if shouldDisplayComponent(from: value, basedOn: fragment) {
            urlComponents.fragment = decoder.fragment
        }

        return self.generateFormattedString(
            from: urlComponents,
            useEncodedHost: hostContainsLookalikeCharacters)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL {

    /// Formats the URL, using the provided format style.
    ///
    /// Use this method when you want to format a single URL value with a
    /// specific format style, or call it repeatedly with different format
    /// styles.
    ///
    /// - Parameter format: The format style to apply when formatting the URL.
    /// - Returns: A formatted string representation of the URL.
    #if FOUNDATION_FRAMEWORK
    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == URL {
        format.format(self)
    }
    #else
    public func formatted<F: FoundationEssentials.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == URL {
        format.format(self)
    }
    #endif

    /// Formats the URL using a default format style.
    ///
    /// Use this method to create a string representation of a URL using the
    /// default ``URL/FormatStyle`` configuration. The default style creates a
    /// string with the scheme, host, and path, but not the port or query.
    ///
    /// To customize formatting of the URL, use ``URL/formatted(_:)``, passing
    /// in a customized ``FormatStyle``.
    ///
    /// - Returns: A string representation of the URL, formatted according to
    ///   the default format style.
    public func formatted() -> String {
        self.formatted(.url)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public extension FormatStyle where Self == URL.FormatStyle {
    /// A style for formatting a URL.
    ///
    /// Use the dot-notation form of this type property when the call point allows the use of
    /// ``URL/FormatStyle``. You typically do this when calling the ``URL/formatted(_:)`` method
    /// of ``URL``.
    ///
    /// The format style provided by this static accessor provides a default behavior. To
    /// customize formatting behavior, use the modifiers in Customizing style behavior.
    ///
    /// The following example shows the use of a customized URL format style, created by
    /// modifying the default style. The custom style strips the scheme and port and omits the
    /// `www` subdomain, but leaves the path intact. This produces a simplified URL
    /// representation that a browser could use as a window title.
    ///
    /// ```swift
    /// let url = URL(string: "http://www.example.com:8080/path/to/file.txt")!
    /// let formatted = url.formatted(.url
    ///     .scheme(.never)
    ///     .host(.omitSpecificSubdomains(["www"]))
    ///     .port(.never)) // "example.com/path/to/file.txt"
    /// ```
    static var url: Self { .init() }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public extension ParseableFormatStyle where Self == URL.FormatStyle {
    static var url: Self { .init() }
}
