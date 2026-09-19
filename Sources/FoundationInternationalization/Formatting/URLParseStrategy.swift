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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension URL {
    fileprivate typealias Component = URL.FormatStyle.Component

    /// A parse strategy for creating URLs from formatted strings.
    ///
    /// Create an explicit ``URL/ParseStrategy`` to parse multiple strings according to the same parse strategy. The following example creates a customized strategy, then applies it to multiple URL candidate strings.
    ///
    /// ```swift
    /// let strategy = URL.ParseStrategy(
    /// scheme: .defaultValue("https"),
    /// user: .optional,
    /// password: .optional,
    /// host: .required,
    /// port: .optional,
    /// path: .required,
    /// query: .required,
    /// fragment: .optional)
    /// let urlStrings = [
    /// "example.com?key1=value1", // no scheme or path
    /// "https://example.com?key2=value2", // no path
    /// "https://example.com", // no query
    /// "https://example.com/path?key4=value4", // complete
    /// "//example.com/path?key5=value5" // complete except for default-able scheme
    /// ]
    /// let urls = urlStrings.map { try? strategy.parse($0) } // [nil, nil, nil, Optional(https://example.com/path?key4=value4), Optional(https://example.com/path?key5=value5)]
    /// ```
    ///
    ///
    /// You don't need to instantiate a parse strategy instance to parse a single string. Instead, use the URL initializer ``URL/init(_:strategy:)``, passing in a string to parse and a customized strategy, typically created with one of the static accessors. The following example parses a URL string, with a custom strategy that provides a default value for the port component if the source string doesn't specify one.
    ///
    /// ```swift
    /// let urlString = "https://internal.example.com/path/to/endpoint?key=value"
    /// let url = try? URL(urlString, strategy: .url
    /// .port(.defaultValue(8080))) // https://internal.example.com:8080/path/to/endpoint?key=value
    ///
    /// ```
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public struct ParseStrategy : Codable, Hashable, Sendable {
        /// The strategy to parse the `scheme` component.
        var scheme: ComponentParseStrategy<String>
        /// The strategy to parse the `user` component.
        var user: ComponentParseStrategy<String>
        /// The strategy to parse the `password` component.
        var password: ComponentParseStrategy<String>
        /// The strategy to parse the `host` component.
        var host: ComponentParseStrategy<String>
        /// The strategy to parse the `port` component.
        var port: ComponentParseStrategy<Int>
        /// The strategy to parse the `path` component.
        var path: ComponentParseStrategy<String>
        /// The strategy to parse the `query` component.
        var query: ComponentParseStrategy<String>
        /// The strategy to parse the `fragment` component.
        var fragment: ComponentParseStrategy<String>

        private var requiredComponentsValue: UInt {
            var value = 0
            value |= (scheme == .required) ? Component.scheme.rawValue : 0
            value |= (user == .required) ? Component.user.rawValue : 0
            value |= (password == .required) ? Component.password.rawValue : 0
            value |= (host == .required) ? Component.host.rawValue : 0
            value |= (port == .required) ? Component.port.rawValue : 0
            value |= (path == .required) ? Component.path.rawValue : 0
            value |= (query == .required) ? Component.query.rawValue : 0
            value |= (fragment == .required) ? Component.fragment.rawValue : 0
            return UInt(value)
        }

        var defaultValues: [Int : String] {
            var values: [Int : String] = [:]
            if case .defaultValue(let value) = scheme {
                values[Component.scheme.rawValue] = value
            }
            if case .defaultValue(let value) = user {
                values[Component.user.rawValue] = value
            }
            if case .defaultValue(let value) = password {
                values[Component.password.rawValue] = value
            }
            if case .defaultValue(let value) = host {
                values[Component.host.rawValue] = value
            }
            if case .defaultValue(let value) = port {
                values[Component.port.rawValue] = String(value)
            }
            if case .defaultValue(let value) = path {
                values[Component.path.rawValue] = value
            }
            if case .defaultValue(let value) = query {
                values[Component.query.rawValue] = value
            }
            if case .defaultValue(let value) = fragment {
                values[Component.fragment.rawValue] = value
            }
            return values
        }

        /// Creates a new `ParseStrategy` with the given configurations.
        /// - Parameters:
        ///   - scheme: The strategy to use for parsing the `scheme`.
        ///   - user: The strategy to use for parsing the `user`.
        ///   - password: The strategy to use for parsing the `password`.
        ///   - host: The strategy to use for parsing the `host`.
        ///   - port: The strategy to use for parsing the `port`.
        ///   - path: The strategy to use for parsing the `path`.
        ///   - query: The strategy to use for parsing the `query`.
        ///   - fragment: The strategy to use for parsing the `fragment`.
        public init(
            scheme: ComponentParseStrategy<String> = .required,
            user: ComponentParseStrategy<String> = .optional,
            password: ComponentParseStrategy<String> = .optional,
            host: ComponentParseStrategy<String> = .required,
            port: ComponentParseStrategy<Int> = .optional,
            path: ComponentParseStrategy<String> = .optional,
            query: ComponentParseStrategy<String> = .optional,
            fragment: ComponentParseStrategy<String> = .optional) {
                self.scheme = scheme
                self.user = user
                self.password = password
                self.host = host
                self.port = port
                self.path = path
                self.query = query
                self.fragment = fragment
        }

        internal init(format: URL.FormatStyle, lenient: Bool) {
            @inline(__always)
            func isComponentRequired(_ component: URL.FormatStyle.ComponentDisplayOption) -> Bool {
                return component.option == .displayed && component.condition == .none
            }

            self.scheme = isComponentRequired(format.scheme) ? .required : .optional
            self.user = isComponentRequired(format.user) ? .required : .optional
            self.password = isComponentRequired(format.password) ? .required : .optional
            let hostRequired = format.host.option == .displayed && format.host.condition == .none
            self.host = hostRequired ? .required : .optional
            self.port = isComponentRequired(format.port) ? .required : .optional
            self.path = isComponentRequired(format.path) ? .required : .optional
            self.query = isComponentRequired(format.query) ? .required : .optional
            self.fragment = isComponentRequired(format.fragment) ? .required : .optional
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.ParseStrategy {
    /// The strategy used to parse one component of a URL.
    ///
    /// Use this type with the ``URL/ParseStrategy`` initializer and static accessors, or its modifier methods, to specify behavior for parsing components of a URL. This allows you to reject URL candidate strings that lack required components — such as a scheme, host, or path — or to fill in default values while parsing.
    public enum ComponentParseStrategy<Component : Codable & Hashable & Sendable> : Codable, Hashable, CustomStringConvertible, Sendable {
        /// Denotes that the component is required to exists in order to consider the URL valid
        case required
        /// Denotes that the component is optional
        case optional
        /// If the component is missing, assume it has the attached default value
        case defaultValue(Component)

        private typealias RequiredCodingKeys = EmptyCodingKeys
        private typealias OptionalCodingKeys = EmptyCodingKeys
        private typealias DefaultValueCodingKeys = DefaultAssociatedValueCodingKeys1

        public var description: String {
            switch self {
            case .required:
                return "required"
            case .optional:
                return "optional"
            case .defaultValue(let value):
                return "assumeValueIfMissing(\(String(describing: value))"
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.ParseStrategy {
    /// Modifies a parse strategy to parse a URL's scheme component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the scheme component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func scheme(_ strategy: ComponentParseStrategy<String> = .required) -> Self {
        var new = self
        new.scheme = strategy
        return new
    }

    /// Modifies a parse strategy to parse a URL's user component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the user component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func user(_ strategy: ComponentParseStrategy<String> = .optional) -> Self {
        var new = self
        new.user = strategy
        return new
    }

    /// Modifies a parse strategy to parse a URL's password component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the password component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func password(_ strategy: ComponentParseStrategy<String> = .optional) -> Self {
        var new = self
        new.password = strategy
        return new
    }

    /// Modifies a parse strategy to parse a URL's host component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the host component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func host(_ strategy: ComponentParseStrategy<String> = .required) -> Self {
        var new = self
        new.host = strategy
        return new
    }

    /// Modifies a parse strategy to parse a URL's port component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the port component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func port(_ strategy: ComponentParseStrategy<Int> = .optional) -> Self {
        var new = self
        new.port = strategy
        return new
    }

    /// Modifies a parse strategy to parse a URL's path component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the path component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func path(_ strategy: ComponentParseStrategy<String> = .optional) -> Self {
        var new = self
        new.path = strategy
        return new
    }

    /// Modifies a parse strategy to parse a URL's query component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the query component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func query(_ strategy: ComponentParseStrategy<String> = .optional) -> Self {
        var new = self
        new.query = strategy
        return new
    }

    /// Modifies a parse strategy to parse a URL's fragment component in accordance with the provided behavior.
    ///
    /// - Parameter strategy: A strategy for parsing the fragment component.
    /// - Returns: A modified ``URL/ParseStrategy`` that incorporates the specified behavior.
    public func fragment(_ strategy: ComponentParseStrategy<String> = .optional) -> Self {
        var new = self
        new.fragment = strategy
        return new
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.ParseStrategy : ParseStrategy {
    fileprivate typealias Component = URL.FormatStyle.Component

    internal func formatStyle() -> URL.FormatStyle {
        // Simply construct a FormatStyle that displays everything
        // since we can't infer when a component *should not* be
        // displayed based on `ComponentParseStrategy`.
        return URL.FormatStyle(
            scheme: .always,
            user: .always,
            password: .always,
            host: .always,
            port: .always,
            path: .always,
            query: .always,
            fragment: .always)
    }

    private func validate(_ components: URLComponents) -> Bool {
        func isRequired(_ component: Component) -> Bool {
            return requiredComponentsValue & UInt(component.rawValue) != 0
        }
        let invalid = (
            (isRequired(.scheme) && components.scheme == nil) ||
            (isRequired(.user) && components.user == nil) ||
            (isRequired(.password) && components.password == nil) ||
            (isRequired(.host) && components.host == nil) ||
            (isRequired(.port) && components.port == nil) ||
            (isRequired(.path) && components.path.isEmpty) ||
            (isRequired(.query) && components.query == nil) ||
            (isRequired(.fragment) && components.fragment == nil)
        )
        return !invalid
    }

    private func fillDefaultValues(for component: inout URLComponents) {
        if component.scheme?.isEmpty ?? true {
            component.scheme = defaultValues[Component.scheme.rawValue]
        }
        if component.user?.isEmpty ?? true {
            component.user = defaultValues[Component.user.rawValue]
        }
        if component.password?.isEmpty ?? true {
            component.password = defaultValues[Component.password.rawValue]
        }
        if component.host?.isEmpty ?? true {
            component.host = defaultValues[Component.host.rawValue]
        }
        if component.port == nil,
           let defaultPort = defaultValues[Component.port.rawValue] {
            component.port = Int(defaultPort)
        }
        if component.path.isEmpty {
            component.path = defaultValues[Component.path.rawValue] ?? ""
        }
        if component.query?.isEmpty ?? true {
            component.query = defaultValues[Component.query.rawValue]
        }
        if component.fragment?.isEmpty ?? true {
            component.fragment = defaultValues[Component.fragment.rawValue]
        }
    }

    internal func matchURL(in string: some StringProtocol, url: inout URL?) -> Range<String.Index>? {
        let endIndex = string.firstIndex { $0.isWhitespace } ?? string.endIndex
        let matchRange = string.startIndex..<endIndex
        let urlString = String(string[matchRange])
        guard var components = URLComponents(string: urlString) else {
            url = nil
            return nil
        }
        guard validate(components) else {
            url = nil
            return nil
        }
        fillDefaultValues(for: &components)
        url = components.url
        return matchRange
    }

    /// Parses a URL string in accordance with this strategy and returns the parsed value.
    ///
    /// Use this method to repeatedly parse URL strings with the same
    /// ``URL/ParseStrategy``. To parse a single URL string, use the URL
    /// initializer ``URL/init(_:strategy:)``.
    ///
    /// This method throws an error if the parse strategy can't parse the
    /// provided string.
    ///
    /// - Parameter value: The string to parse.
    /// - Returns: The parsed URL value.
    public func parse(_ value: String) throws -> URL {
        var url: URL?
        let result = matchURL(in: value, url: &url)
        guard result != nil, let url else {
            let url = URL(string: "https://user:password@www.example.com/path?color=red#name")!
            throw parseError(value, exampleFormattedString: self.formatStyle().format(url))
        }
        return url
    }

    private static func match(url: inout URL?, inString string: String, defaultValues: [Int: String], requiredComponentsValue: UInt) {
        if defaultValues.isEmpty { return }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension ParseStrategy where Self == URL.ParseStrategy {
    /// A parse strategy for URLs.
    ///
    /// Use the dot-notation form of this type property when the call point allows the use of
    /// ``URL/ParseStrategy``. Typically, you use this with the URL initializer ``URL/init(_:strategy:)``.
    public static var url: Self {
        .init()
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL {
    /// Creates a new `URL` by parsing the given representation.
    /// - Parameters:
    ///   - value: A representation of a URL. The type of the representation is specified
    ///     by `ParseStrategy.ParseInput`.
    ///   - strategy: The parse strategy to parse `value` whose `ParseInput` is `URL`.
#if FOUNDATION_FRAMEWORK
    public init<T: Foundation.ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == Self {
        self = try strategy.parse(value)
    }
#else
    public init<T: FoundationEssentials.ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == Self {
        self = try strategy.parse(value)
    }
#endif
}

// MARK: - Regex
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL.ParseStrategy : CustomConsumingRegexComponent {
    /// The type returned when capturing matching substrings with this strategy.
    ///
    /// This strategy returns the ``URL`` type when performing regex capture.
    public typealias RegexOutput = URL

    /// Processes the input string within the specified bounds, beginning at the given index, and returns the end position of the match and the produced output.
    ///
    /// Don't call this method directly. Regular expression matching and capture
    /// calls it automatically when matching substrings.
    ///
    /// - Parameters:
    ///   - input: An input string to match against.
    ///   - index: The index within `input` at which to begin searching.
    ///   - bounds: The bounds within `input` in which to search.
    /// - Returns: The upper bound where the match terminates and a matched instance, or `nil` if there isn't a match.
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: URL)? {
        guard index < bounds.upperBound else {
            return nil
        }
        let urlString = input[index ..< bounds.upperBound]
        var url: URL?
        let result = matchURL(in: urlString, url: &url)
        guard let result, let url else {
            return nil
        }
        return (upperBound: result.upperBound, output: url)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == URL.ParseStrategy {
    public static func url(scheme: URL.ParseStrategy.ComponentParseStrategy<String> = .required,
       user: URL.ParseStrategy.ComponentParseStrategy<String> = .optional,
       password: URL.ParseStrategy.ComponentParseStrategy<String> = .optional,
       host: URL.ParseStrategy.ComponentParseStrategy<String> = .required,
       port: URL.ParseStrategy.ComponentParseStrategy<Int> = .optional,
       path: URL.ParseStrategy.ComponentParseStrategy<String> = .optional,
       query: URL.ParseStrategy.ComponentParseStrategy<String> = .optional,
       fragment: URL.ParseStrategy.ComponentParseStrategy<String> = .optional) -> Self {
        return URL.ParseStrategy(
            scheme: scheme,
            user: user,
            password: password,
            host: host,
            port: port,
            path: path,
            query: query,
            fragment: fragment)
    }
}
