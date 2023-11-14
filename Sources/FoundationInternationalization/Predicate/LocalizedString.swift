//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions {
    public struct StringLocalizedStandardContains<
        Root : PredicateExpression,
        Other : PredicateExpression
    > : PredicateExpression where
        Root.Output : StringProtocol,
        Other.Output : StringProtocol
    {
        public typealias Output = Bool
        
        public let root: Root
        public let other: Other
        
        public init(root: Root, other: Other) {
            self.root = root
            self.other = other
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try root.evaluate(bindings).localizedStandardContains(try other.evaluate(bindings))
        }
    }
    
    public static func build_localizedStandardContains<Root, Other>(_ root: Root, _ other: Other) -> StringLocalizedStandardContains<Root, Other> {
        StringLocalizedStandardContains(root: root, other: other)
    }
}

@available(FoundationPreview 0.3, *)
extension PredicateExpressions.StringLocalizedStandardContains : CustomStringConvertible {
    public var description: String {
        "StringLocalizedStandardContains(root: \(root), other: \(other))"
    }
}

@available(FoundationPreview 0.3, *)
extension PredicateExpressions.StringLocalizedStandardContains : DebugStringConvertiblePredicateExpression where Root : DebugStringConvertiblePredicateExpression, Other : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(root.debugString(state: &state)).localizedStandardContains(\(other.debugString(state: &state)))"
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.StringLocalizedStandardContains : StandardPredicateExpression where Root : StandardPredicateExpression, Other : StandardPredicateExpression {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.StringLocalizedStandardContains : Codable where Root : Codable, Other : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(root)
        try container.encode(other)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        root = try container.decode(Root.self)
        other = try container.decode(Other.self)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.StringLocalizedStandardContains : Sendable where Root : Sendable, Other : Sendable {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions {
    public struct StringLocalizedCompare<
        Root : PredicateExpression,
        Other : PredicateExpression
    > : PredicateExpression where
        Root.Output : StringProtocol,
        Other.Output : StringProtocol
    {
        public typealias Output = ComparisonResult
        
        public let root: Root
        public let other: Other
        
        public init(root: Root, other: Other) {
            self.root = root
            self.other = other
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try root.evaluate(bindings).localizedCompare(other.evaluate(bindings))
        }
    }
    
    public static func build_localizedCompare<Root, Other>(_ root: Root, _ other: Other) -> StringLocalizedCompare<Root, Other> {
        StringLocalizedCompare(root: root, other: other)
    }
}

@available(FoundationPreview 0.3, *)
extension PredicateExpressions.StringLocalizedCompare : CustomStringConvertible {
    public var description: String {
        "StringLocalizedCompare(root: \(root), other: \(other))"
    }
}

@available(FoundationPreview 0.3, *)
extension PredicateExpressions.StringLocalizedCompare : DebugStringConvertiblePredicateExpression where Root : DebugStringConvertiblePredicateExpression, Other : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(root.debugString(state: &state)).localizedCompare(\(other.debugString(state: &state)))"
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.StringLocalizedCompare : StandardPredicateExpression where Root : StandardPredicateExpression, Other : StandardPredicateExpression {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.StringLocalizedCompare : Codable where Root : Codable, Other : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(root)
        try container.encode(other)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        root = try container.decode(Root.self)
        other = try container.decode(Other.self)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.StringLocalizedCompare : Sendable where Root : Sendable, Other : Sendable {}

#endif
