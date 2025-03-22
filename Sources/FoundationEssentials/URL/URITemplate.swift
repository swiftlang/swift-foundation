#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(OrderedCollections)
internal import OrderedCollections
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

extension URL {
    /// A template for constructing a URL from variable expansions.
    ///
    /// This is an template that can be expanded into
    /// a ``URL`` by calling ``URL(template:variables:)``.
    ///
    /// Templating has a rich set of options for substituting various parts of URLs. See
    /// [RFC 6570](https://datatracker.ietf.org/doc/html/rfc6570) for
    /// details.
    ///
    /// ### Example
    /// ```swift
    /// let template = URL.Template("http://www.example.com/foo{?query,number}")
    /// let url = URL(
    ///     template: template,
    ///     variables: [
    ///         "query": "bar baz",
    ///         "number": "234",
    ///     ]
    /// )
    /// ```
    /// The resulting URL will be
    /// ```text
    /// http://www.example.com/foo?query=bar%20baz&number=234
    /// ```
    @available(FoundationPreview 6.2, *)
    public struct Template: Sendable, Hashable {
        var elements: [Element] = []

        enum Element: Sendable, Hashable {
            case literal(String)
            case expression(Expression)
        }
    }
}

// MARK: - Parse

extension URL.Template {
    /// Creates a new template from its text form.
    ///
    /// The template string needs to be a valid RFC 6570 template.
    ///
    /// This will parse the template and throw an error if the template is invalid.
    public init(_ template: String) throws {
        self.init()

        var remainder = template[...]

        func copyLiteral(upTo end: String.Index) {
            guard
                remainder.startIndex < end
            else { return }
            let literal = remainder[remainder.startIndex..<end]
            let escaped = String(literal).normalizedAddingPercentEncoding(
                withAllowedCharacters: .unreservedReserved
            )
            elements.append(.literal(escaped))
        }

        while let match = remainder.firstMatch(of: URL.Template.Global.shared.uriTemplateRegex) {
            defer {
                remainder = remainder[match.range.upperBound..<remainder.endIndex]
            }
            copyLiteral(upTo: match.range.lowerBound)
            let expression = try Expression(String(match.output.1))
            elements.append(.expression(expression))
        }
        copyLiteral(upTo: remainder.endIndex)
    }
}

// MARK: -

extension URL.Template: CustomStringConvertible {
    public var description: String {
        elements.reduce(into: "") {
            $0.append("\($1)")
        }
    }
}

extension URL.Template.Element: CustomStringConvertible {
    var description: String {
        switch self {
        case .literal(let l): l
        case .expression(let e): "{\(e)}"
        }
    }
}
