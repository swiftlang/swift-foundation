//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// A type-erased token that stands in for a coding strategy expression at the
/// `@CodableBy` / `@DecodableBy` / `@EncodableBy` attribute site.
///
/// `CodingStrategySyntax` exists **solely** to work around the lack of attachee
/// type information in attached macros and to provide static member syntax.
/// It mirrors the static members found on the strategy protocols but is
/// non-generic, avoiding the type-inference failures that occur when the
/// compiler tries to resolve generic parameters (like `T` in
/// `LosslessStringCodingStrategy<T>`) at the attribute site — where no
/// connection to the field type exists.
///
/// ## Example
///
///     @CodableBy(.losslessStringConversion)
///     let port: UInt16
///
///     @CodableBy([.pass : .losslessStringConversion])
///     let scores: [String:Int]
///
/// The expression `.losslessStringConversion` resolves as
/// `CodingStrategySyntax.losslessStringConversion` at the attribute site.
/// The macro then splices the text `.losslessStringConversion()` into the expansion,
/// where it resolves as `LosslessStringCodingStrategy<UInt16>` against the
/// actual strategy protocol — with the type witness providing inference.
public struct CodingStrategySyntax: Sendable, Hashable {
    /// This initializer is never actually called at runtime; the macro
    /// intercepts the attribute before evaluation. It exists only so that
    /// static members can return `Self`.
    public init() {}
}

/// Built-in coding strategy tokens and extension point.
///
/// ## Extending with Custom Strategies
///
/// To add a new coding strategy that works with `CodingStrategySyntax`:
///
/// 1. Define a type conforming to `CodingStrategy` (or `EncodingStrategy` /
///    `DecodingStrategy`) with a `Value` associated type.
///
/// 2. Add a corresponding static member here on `CodingStrategySyntax`
///    so the attribute site can resolve it via dot-syntax.
///
/// Each static member here must mirror a real strategy type in the
/// `CodingStrategy` extensions.
///
/// ### Specially-Treated Strategies
///
/// ``pass`` and ``losslessStringConversion`` are treated specially by the
/// macro: their strategy types are non-generic (or the macro can infer the
/// generic parameter directly from the property type), so the macro splices
/// them *without* parentheses — e.g. `.losslessStringConversion` in the
/// attribute becomes `LosslessStringCodingStrategy<FieldType>` in the
/// expansion.
///
/// ### Custom Strategies with a Generic `Value` Type
///
/// Every other custom strategy extension whose concrete strategy type
/// includes a generic `Value` parameter **must** use a `static func` (not a
/// `static var`) that accepts and returns `CodingStrategySyntax`,
/// because property declarations cannot be internally generic. At the
/// expansion site the macro emits the call with parentheses, allowing the
/// real generic strategy type to bind `Value` through type inference.
///
/// ```swift
/// // In CodingStrategySyntax:
/// public static func clamping<T: Comparable>(
///     _ range: ClosedRange<T>
/// ) -> CodingStrategySyntax { .init() }
///
/// // The corresponding real strategy:
/// public struct ClampingCodingStrategy<Value: Comparable>: CommonCodingStrategy { … }
///
/// // And the matching extension on CommonCodingStrategy:
/// extension CommonCodingStrategy {
///     public static func clamping<T: Comparable>(
///         _ range: ClosedRange<T>
///     ) -> ClampingCodingStrategy<T> where Self == ClampingCodingStrategy<T> {
///         .init(range)
///     }
/// }
/// ```
extension CodingStrategySyntax {
    /// Use the value's own encodable or decodable conformance (identity/passthrough). Synonym for `.passthrough`.
    // TODO: static var `_` would be preferable, a la serde-with package, but it causes AST generation errors in Swift Syntax.
    public static var pass: CodingStrategySyntax { .init() }
    
    /// Encode/decode a value as a string using `LosslessStringConvertible`.
    public static var losslessStringConversion: CodingStrategySyntax { .init() }
}

/// Apply an inner strategy element-wise to an array.
extension CodingStrategySyntax: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = CodingStrategySyntax
    
    public init(arrayLiteral elements: CodingStrategySyntax...) {}
}

extension CodingStrategySyntax: ExpressibleByDictionaryLiteral {
    public typealias Key = CodingStrategySyntax
    public typealias Value = CodingStrategySyntax
    
    public init(dictionaryLiteral elements: (CodingStrategySyntax, CodingStrategySyntax)...) {}
}
