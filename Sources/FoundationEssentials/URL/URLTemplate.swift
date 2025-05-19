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
    /// ### Example 1
    ///
    /// ```swift
    /// let template = URL.Template("http://www.example.com/foo{?query,number}")!
    /// let url = URL(
    ///     template: template,
    ///     variables: [
    ///         .query: "bar baz",
    ///         .number: "234",
    ///     ]
    /// )
    ///
    /// extension URL.Template.VariableName {
    ///     static var query: URL.Template.VariableName { .init("query") }
    ///     static var number: URL.Template.VariableName { .init("number") }
    /// }
    /// ```
    /// The resulting URL will be
    /// ```text
    /// http://www.example.com/foo?query=bar%20baz&number=234
    /// ```
    ///
    /// ### Usage
    ///
    /// Templates provide a description of a URL space and define how URLs can
    /// be constructed given specific variable values. Their intended use is,
    /// for example, to allow a server to communicate to a client how to
    /// construct URLs for particular resources.
    ///
    /// For each specific resource, an API contract is required to clearly
    /// define the variables applicable to that resource and its associated
    /// template. For example, such an API contract might specify that the
    /// variable `query` is mandatory and must be an alphanumeric string
    /// while the variable `number` is optional and must be a positive integer
    /// if provided. The server could then provide the client with a template
    /// such as `http://www.example.com/foo{?query,number}`, which the client
    /// can subsequently use to substitute variables accordingly.
    ///
    /// An API contract is necessary to define which substitutions are valid
    /// within a given URL space. There is no guarantee that every possible
    /// expansion of variable expressions corresponds to an existing resource
    /// URL; indeed, some expansions may not even produce a valid URL. Only
    /// the API specification itself can determine which expansions are
    /// expected to yield valid URLs corresponding to existing resources.
    ///
    /// ### Example 2
    ///
    /// Here’s an example, that illustrates how to define a specific set of variables:
    /// ```swift
    /// struct MyQueryTemplate: Sendable, Hashable {
    ///     var template: URL.Template
    ///
    ///     init?(_ template: String) {
    ///         guard let t = URL.Template(template) else { return nil }
    ///         self.template = t
    ///     }
    /// }
    ///
    /// struct MyQuery: Sendable, Hashable {
    ///     var query: String
    ///     var number: Int?
    ///
    ///     var variables: [URL.Template.VariableName: URL.Template.Value] {
    ///         var result: [URL.Template.VariableName: URL.Template.Value] = [
    ///             .query: .text(query)
    ///         ]
    ///         if let number {
    ///             result[.number] = .text("\(number)")
    ///         }
    ///         return result
    ///     }
    /// }
    ///
    /// extension URL.Template.VariableName {
    ///     static var query: URL.Template.VariableName { .init("query") }
    ///     static var number: URL.Template.VariableName { .init("number") }
    /// }
    ///
    /// extension URL {
    ///     init?(
    ///         template: MyQueryTemplate,
    ///         query: MyQuery
    ///     ) {
    ///         self.init(
    ///             template: template.template,
    ///             variables: query.variables
    ///         )
    ///     }
    /// }
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

@available(FoundationPreview 6.2, *)
extension URL.Template {
    /// Creates a new template from its text form.
    ///
    /// The template string needs to be a valid RFC 6570 template.
    ///
    /// This will parse the template and return `nil` if the template is invalid.
    public init?(_ template: String) {
        do {
            self.init()

            var remainder = template[...]

            func copyLiteral(upTo end: String.Index) {
                guard remainder.startIndex < end else { return }
                let literal = remainder[remainder.startIndex..<end]
                let escaped = String(literal).normalizedAddingPercentEncoding(
                    withAllowedCharacters: .unreservedReserved
                )
                elements.append(.literal(escaped))
            }

            while let match = remainder.firstMatch(of: URL.Template.Global.shared.uriTemplateRegex) {
                copyLiteral(upTo: match.range.lowerBound)
                let expression = try Expression(String(match.output.1))
                elements.append(.expression(expression))
                remainder = remainder[match.range.upperBound..<remainder.endIndex]
            }
            copyLiteral(upTo: remainder.endIndex)
        } catch {
            return nil
        }
    }
}

// MARK: -

@available(FoundationPreview 6.2, *)
extension URL.Template: CustomStringConvertible {
    public var description: String {
        elements.reduce(into: "") {
            $0.append("\($1)")
        }
    }
}

@available(FoundationPreview 6.2, *)
extension URL.Template.Element: CustomStringConvertible {
    var description: String {
        switch self {
        case .literal(let l): l
        case .expression(let e): "{\(e)}"
        }
    }
}
