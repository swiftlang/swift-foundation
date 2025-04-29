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

@available(FoundationPreview 6.2, *)
extension URL.Template {
    /// The value of a variable used for expanding a template.
    ///
    /// A value can either be some text, a list, or an associate list (a dictionary).
    ///
    /// ### Examples
    /// ```swift
    /// let hello: URL.Template.Value = .text("Hello World!")
    /// let list: URL.Template.Value = .list(["red", "green", "blue"])
    /// let keys: URL.Template.Value = .associativeList([
    ///     "semi": ";",
    ///     "dot": ".",
    ///     "comma": ",",
    /// ])
    /// ```
    /// Alternatively, for constants, the `ExpressibleBy…Literal` implementations
    /// can be used, i.e.
    /// ```swift
    /// let hello: URL.Template.Value = "Hello World!"
    /// let list: URL.Template.Value = ["red", "green", "blue"]
    /// let keys: URL.Template.Value = [
    ///     "semi": ";",
    ///     "dot": ".",
    ///     "comma": ",",
    /// ]
    /// ```
    public struct Value: Sendable, Hashable {
        let underlying: Underlying
    }
}

@available(FoundationPreview 6.2, *)
extension URL.Template.Value {
    /// A text value to be used with a ``URL.Template``.
    public static func text(_ text: String) -> URL.Template.Value {
        URL.Template.Value(underlying: .text(text))
    }

    /// A list value (an array of `String`s) to be used with a ``URL.Template``.
    public static func list(_ list: some Sequence<String>) -> URL.Template.Value {
        URL.Template.Value(underlying: .list(Array(list)))
    }

    /// An associative list value (ordered key-value pairs) to be used with a ``URL.Template``.
    public static func associativeList(_ list: some Sequence<(key: String, value: String)>) -> URL.Template.Value {
        URL.Template.Value(underlying: .associativeList(OrderedDictionary(uniqueKeysWithValues: list)))
    }
}

// MARK: -

@available(FoundationPreview 6.2, *)
extension URL.Template.Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

@available(FoundationPreview 6.2, *)
extension URL.Template.Value: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self.init(underlying: .list(elements))
    }
}

@available(FoundationPreview 6.2, *)
extension URL.Template.Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(underlying: .associativeList(OrderedDictionary(uniqueKeysWithValues: elements)))
    }
}

// MARK: -

@available(FoundationPreview 6.2, *)
extension URL.Template.Value: CustomStringConvertible {
    public var description: String {
        switch underlying {
        case .text(let v): return v
        case .list(let v): return "\(v)"
        case .associativeList(let v): return "\(v)"
        }
    }
}

// MARK: -

extension URL.Template.Value {
    enum Underlying: Sendable, Hashable {
        case text(String)
        case list([String])
        case associativeList(OrderedDictionary<String, String>)
    }
}
