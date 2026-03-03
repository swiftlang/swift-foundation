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


#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(OrderedCollections)
internal import OrderedCollections
#endif

public struct JSONPrimitiveDecoder: JSONDecoderProtocol {
    public typealias Options = NewJSONDecoder.Options
    
    // Structures with container nesting deeper than this limit are not valid.
    @usableFromInline
    internal static var maximumRecursionDepth: Int { 512 }
    
    @usableFromInline
    internal var value: JSONPrimitive
    
    @usableFromInline
    internal let options: Options
    
    @usableFromInline
    internal var depth: Int
    
    public internal(set) var codingPath: CodingPath
    
    public init(keysAndValues: JSONIntermediateKeyValueStorage, codingPath: CodingPath) {
        self.value = .dictionary(keysAndValues.storage)
        self.options = keysAndValues.options
        self.codingPath = codingPath
        self.depth = 0
    }
    
    // TODO: Public?
    public init(value: JSONPrimitive, options: Options = .init()) {
        self.value = value
        self.options = options
        self.codingPath = .init([])
        self.depth = 0
    }
    
    @usableFromInline
    internal init(value: JSONPrimitive, options: Options, codingPath: CodingPath) {
        self.value = value
        self.options = options
        self.codingPath = codingPath
        self.depth = 0
    }
    
    @usableFromInline
    internal init(value: JSONPrimitive, options: Options, codingPath: CodingPath, depth: Int) {
        self.value = value
        self.options = options
        self.codingPath = codingPath
        self.depth = depth
    }
    
    public struct StructDecoder: CommonDictionaryDecoder, CommonStructDecoder, JSONDictionaryDecoder {
        public typealias FieldDecoder = JSONPrimitiveDecoder.FieldDecoder
        public typealias ValueDecoder = JSONPrimitiveDecoder
        public typealias KeyDecoder = JSONPrimitiveDecoder
        
        internal var dictionary: OrderedDictionary<String, JSONPrimitive>
        
        internal let options: Options
        internal let depth: Int
        
        public let sizeHint: Int?
        public let codingPath: CodingPath
        
        init(elements: some Sequence<(key: String, value: JSONPrimitive)>, options: Options, codingPath: CodingPath, depth: Int = 0) throws(CodingError.Decoding) {
            // Check depth limit before creating container
            guard depth < JSONPrimitiveDecoder.maximumRecursionDepth else {
                throw CodingError.Decoding(kind: .dataCorrupted, debugDescription: "Too many nested arrays or dictionaries")
            }
            
            // TODO: I'm not exactly convinced this is right. We're hiding duplicate fields from the client that they would have seen with the parser variant.
            self.dictionary = OrderedDictionary(elements, uniquingKeysWith: { (existing, new) in existing })
            self.sizeHint = self.dictionary.count
            self.options = options
            self.codingPath = codingPath
            self.depth = depth + 1
        }
        
        init(dictionary: OrderedDictionary<String, JSONPrimitive>, options: Options, codingPath: CodingPath, depth: Int = 0) throws(CodingError.Decoding) {
            // Check depth limit before creating container
            guard depth < JSONPrimitiveDecoder.maximumRecursionDepth else {
                throw CodingError.Decoding(kind: .dataCorrupted, debugDescription: "Too many nested arrays or dictionaries")
            }
            
            self.dictionary = dictionary
            self.sizeHint = self.dictionary.count
            self.options = options
            self.codingPath = codingPath
            self.depth = depth + 1
        }
                
        public mutating func decodeEachField(_ fieldDecoderClosure: (inout FieldDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout JSONPrimitiveDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
            var fieldDecoder = FieldDecoder(string: "")
            var valueDecoder = JSONPrimitiveDecoder(value: .null, options: self.options, codingPath: self.codingPath.appending(""), depth: self.depth)
            while let (key, value) = dictionary.elements.first {
                fieldDecoder.string = key
                valueDecoder.value = value
                valueDecoder.codingPath.replaceLast(with: key)
                try fieldDecoderClosure(&fieldDecoder)
                try valueDecoderClosure(&valueDecoder)
                dictionary.elements.removeFirst()
            }
        }
        
        public mutating func decodeExpectedOrderField(required: Bool, matchingClosure: (UTF8Span) -> Bool, optimizedSafeStringKey: JSONSafeStringKey?, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
            guard let (key, value) = dictionary.elements.first else {
                return !required
            }
            
            let matches: Bool
            if let safeStringKey = optimizedSafeStringKey {
                matches = key == safeStringKey.string.description
            } else {
                matches = matchingClosure(key.utf8Span)
            }
            
            guard matches else {
                return !required
            }
            
            var valueDecoder = JSONPrimitiveDecoder(value: value, options: self.options, codingPath: self.codingPath.appending(key), depth: self.depth)
            try valueDecoderClosure(&valueDecoder)
            dictionary.elements.removeFirst()
            
            return true
        }
        
        public mutating func decodeExpectedOrderField(required: Bool, matchingClosure: (UTF8Span) -> Bool, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
            return try decodeExpectedOrderField(required: required, matchingClosure: matchingClosure, optimizedSafeStringKey: nil, andValue: valueDecoderClosure)
        }

        public mutating func decodeEachKeyAndValue(_ closure: (String, inout ValueDecoder) throws(CodingError.Decoding) -> Bool) throws(CodingError.Decoding) {
            var valueDecoder = JSONPrimitiveDecoder(value: .null, options: self.options, codingPath: self.codingPath.appending(""), depth: self.depth)
            var stop = false
            while let (key, value) = dictionary.elements.first, !stop {
                valueDecoder.codingPath.replaceLast(with: key)
                valueDecoder.value = value
                stop = try closure(key, &valueDecoder)
                dictionary.elements.removeFirst()
            }
        }
        
        public mutating func decodeKeyAndValue(_ closure: (String, inout JSONPrimitiveDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
            guard let (key, value) = dictionary.elements.first else { return false }
            
            var valueDecoder = JSONPrimitiveDecoder(value: value, options: self.options, codingPath: self.codingPath.appending(key), depth: self.depth)
            try closure(key, &valueDecoder)
            dictionary.elements.removeFirst()
            
            return true
        }
        
        public mutating func decodeEachKey(_ keyDecodingClosure: (inout JSONPrimitiveDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout JSONPrimitiveDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
            var decoder = JSONPrimitiveDecoder(value: .null, options: self.options, codingPath: self.codingPath.appending(""))
            while let (key, value) = dictionary.elements.first {
                decoder.codingPath.replaceLast(with: key)
                decoder.value = .string(key)
                try keyDecodingClosure(&decoder)
                
                decoder.value = value
                try valueDecoderClosure(&decoder)
                dictionary.elements.removeFirst()
            }
        }
        
        public mutating func decodeKey(_ keyDecodingClosure: (inout JSONPrimitiveDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout JSONPrimitiveDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
            guard let (key, value) = dictionary.elements.first else { return false }
            
            var decoder = JSONPrimitiveDecoder(value: .string(key), options: self.options, codingPath: self.codingPath.appending(key), depth: self.depth)
            try keyDecodingClosure(&decoder)
            
            decoder.value = value
            try valueDecoderClosure(&decoder)
            dictionary.elements.removeFirst()
            
            return true
        }
        
        
        public mutating func withWrappingDecoder<T>(_ closure: (inout ValueDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
            // TODO: Is this the right behavior with regards to the diictionary? Should we empty the dictionary after this?
            var subDecoder = JSONPrimitiveDecoder(value: .dictionary(Array(self.dictionary)), options: self.options, codingPath: self.codingPath, depth: self.depth)
            return try closure(&subDecoder)
        }
        
        public func prepareIntermediateValueStorage() -> JSONIntermediateKeyValueStorage {
            .init(options: self.options)
        }
    }
    
    public struct FieldDecoder: CommonFieldDecoder, JSONFieldDecoder {
        @usableFromInline
        internal var string: String
        
        @_alwaysEmitIntoClient
        @inlinable
        public func decode<T: DecodingField>(_: T.Type) throws(CodingError.Decoding) -> T {
            return try T.field(for: string)
        }
        
        @inlinable
        public func matches(_ field: some DecodingField) -> Bool {
            return field.matches(self.string)
        }
        
        public func matches(_ key: StaticString) -> Bool {
            return key.description == self.string
        }

    }
    
    public struct ArrayDecoder: CommonArrayDecoder, JSONArrayDecoder {
        public typealias ElementDecoder = JSONPrimitiveDecoder
        
        let array: [JSONPrimitive]
        let options: NewJSONDecoder.Options
        let depth: Int
        public let codingPath: CodingPath
        var elementCodingPath: CodingPath
        var idx: Int = 0
        
        init(array: [JSONPrimitive], options: NewJSONDecoder.Options, codingPath: CodingPath, depth: Int = 0) throws(CodingError.Decoding) {
            // Check depth limit before creating container
            guard depth < JSONPrimitiveDecoder.maximumRecursionDepth else {
                throw CodingError.Decoding(kind: .dataCorrupted, debugDescription: "Too many nested arrays or dictionaries")
            }
            
            self.array = array
            self.options = options
            self.codingPath = codingPath
            self.elementCodingPath = codingPath.appending(index: -1)
            self.depth = depth + 1
        }
        
        public var sizeHint: Int? {
            array.count
        }
                
        public mutating func decodeNext<T: ~Copyable>(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T? {
            if idx == array.endIndex { return nil }
            let value = array[idx]
            idx += 1
            self.elementCodingPath.replaceLast(withIndex: idx)
            var decoder = JSONPrimitiveDecoder(value: value, options: options, codingPath: self.elementCodingPath, depth: self.depth)
            return try closure(&decoder)
        }
        
        public mutating func decodeEachElement(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
            var decoder = JSONPrimitiveDecoder(value: .null, options: options, codingPath: self.elementCodingPath, depth: self.depth)
            for value in array {
                decoder.codingPath.incrementLast()
                decoder.value = value
                try closure(&decoder)
            }
        }
    }

    public mutating func decodeStruct<T: ~Copyable>(_ closure: (inout StructDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        guard case let .dictionary(elements) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "dictionary", at: self.codingPath)
        }

        var decoder = try StructDecoder(elements: elements, options: self.options, codingPath: self.codingPath, depth: self.depth)
        return try closure(&decoder)
    }
    
    public mutating func decodeArray<T: ~Copyable>(_ closure: (inout ArrayDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        guard case let .array(array) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "array", at: self.codingPath)
        }

        var decoder = try ArrayDecoder(array: array, options: self.options, codingPath: self.codingPath, depth: self.depth)
        return try closure(&decoder)
    }
    
    // MARK: - Enum Decoding
    
    /// Decodes an enum case with no associated values from `{"caseName":{}}` format
    public mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (inout FieldDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T {
        guard case let .dictionary(elements) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "dictionary", at: self.codingPath)
        }
        
        guard elements.count == 1 else {
            throw CodingError.dataCorrupted(at: self.codingPath, debugDescription: "Expected exactly one key-value pair for enum case, has \(elements.count)")
        }
        
        let (caseName, caseValue) = elements.first!
        var fieldDecoder = FieldDecoder(string: caseName)
        let result = try closure(&fieldDecoder)
        
        // Verify the value is an empty dictionary
        guard case let .dictionary(innerElements) = caseValue, innerElements.isEmpty else {
            throw CodingError.dataCorrupted(at: self.codingPath, debugDescription: "Expected empty dictionary for value-less enum case")
        }
        
        return result
    }
    
    /// Decodes an enum case with associated values from `{"caseName":{"field1":value1,...}}` format
    public mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (_ caseName: inout FieldDecoder, _ associatedValues: inout StructDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T {
        guard case let .dictionary(elements) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "dictionary", at: self.codingPath)
        }
        
        guard elements.count == 1 else {
            throw CodingError.dataCorrupted(at: self.codingPath, debugDescription: "Expected exactly one key-value pair for enum case, has \(elements.count)")
        }
        
        let (caseName, caseValue) = elements.first!
        var fieldDecoder = FieldDecoder(string: caseName)
        
        // The value should be a dictionary containing the associated values
        guard case let .dictionary(associatedElements) = caseValue else {
            throw value.typeMismatchError(expectedTypeDescription: "dictionary", at: self.codingPath)
        }
        
        var structDecoder = try StructDecoder(elements: associatedElements, options: self.options, codingPath: self.codingPath.appending(caseName), depth: self.depth)
        return try closure(&fieldDecoder, &structDecoder)
    }
        
    // TODO: See below on [Element] decoder for relevant comments.
    public mutating func decode<Key: CodingStringKeyRepresentable, Value: JSONDecodable>(_: [Key:Value].Type, sizeHint: Int = 0) throws(CodingError.Decoding) -> [Key:Value] {
        guard case let .dictionary(elements) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "dictionary", at: self.codingPath)
        }
        
        let options = self.options
        var decoder = JSONPrimitiveDecoder(value: .null, options: options, codingPath: self.codingPath.appending(""), depth: self.depth)
        let mapped = try elements.map { pair throws(CodingError.Decoding) in
            decoder.codingPath.replaceLast(with: pair.key)
            decoder.value = pair.value
            return (try Key.codingStringKeyVisitor.visitString(pair.key), try decoder.decode(Value.self))
        }
        return Dictionary(mapped, uniquingKeysWith: { (existing, new) in existing })
    }
        
    public mutating func decode<Element: JSONDecodable>(_: [Element].Type, sizeHint: Int = 0) throws(CodingError.Decoding) -> [Element] {
        guard case let .array(array) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "array", at: self.codingPath)
        }
        
        let options = self.options
        var decoder = JSONPrimitiveDecoder(value: .null, options: options, codingPath: self.codingPath.appending(index: -1), depth: self.depth)
        return try array.map { el throws(CodingError.Decoding) in
            decoder.codingPath.incrementLast()
            decoder.value = el
            return try decoder.decode(Element.self)
        }
    }
    
    public mutating func decode<Element: JSONDecodableWithContext>(_: [Element].Type, context: inout Element.JSONDecodingContext, sizeHint: Int = 0) throws(CodingError.Decoding) -> [Element] {
        guard case let .array(array) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "array", at: self.codingPath)
        }
        
        let options = self.options
        var decoder = JSONPrimitiveDecoder(value: .null, options: options, codingPath: self.codingPath.appending(index: -1), depth: self.depth)
        return try array.map { el throws(CodingError.Decoding) in
            decoder.codingPath.incrementLast()
            decoder.value = el
            return try decoder.decode(Element.self, context: &context)
        }
    }
}

extension JSONPrimitiveDecoder {
    public func decode(_: Bool.Type) throws(CodingError.Decoding) -> Bool {
        guard case let .bool(bool) = value else {
            throw value.typeMismatchError(expectedType: Bool.self, at: self.codingPath)
        }
        return bool
    }
    
    public func decode(_ hint: Int.Type) throws(CodingError.Decoding) -> Int {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: Int8.Type) throws(CodingError.Decoding) -> Int8 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: Int16.Type) throws(CodingError.Decoding) -> Int16 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: Int32.Type) throws(CodingError.Decoding) -> Int32 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: Int64.Type) throws(CodingError.Decoding) -> Int64 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: UInt.Type) throws(CodingError.Decoding) -> UInt {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: UInt8.Type) throws(CodingError.Decoding) -> UInt8 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: UInt16.Type) throws(CodingError.Decoding) -> UInt16 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: UInt32.Type) throws(CodingError.Decoding) -> UInt32 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: UInt64.Type) throws(CodingError.Decoding) -> UInt64 {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: Float.Type) throws(CodingError.Decoding) -> Float {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_ hint: Double.Type) throws(CodingError.Decoding) -> Double {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedType: hint, at: self.codingPath)
        }
        do {
            return try number[hint]
        } catch {
            fatalError("TODO: Wrap/convert error")
        }
    }
    
    public func decode(_: String.Type) throws(CodingError.Decoding) -> String {
        guard case let .string(string) = value else {
            throw value.typeMismatchError(expectedType: String.self, at: self.codingPath)
        }
        return string
    }
    
    public func decodeString<V: DecodingStringVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V) throws(CodingError.Decoding) -> V.DecodedValue {
        let string = try self.decode(String.self)
        return try visitor.visitString(string)
    }
    
    public func decodeNumber() throws(CodingError.Decoding) -> JSONPrimitive.Number {
        guard case let .number(number) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "number", at: self.codingPath)
        }
        return number
    }
    
    public func decodeNil() throws(CodingError.Decoding) -> Bool {
        return value == .null
    }
    
    public func decodeOptional(_ closure: (inout Self) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
        if try self.decodeNil() {
            return
        }
        var copy = self
        try closure(&copy)
    }
    
    public func decode(_ hint: Date.Type) throws(CodingError.Decoding) -> Date {
        var copy = self
        return try self.options.dateDecodingStrategy.decodeDate(from: &copy)
    }
    
    public func decode(_ hint: Data.Type) throws(CodingError.Decoding) -> Data {
        var copy = self
        return try self.options.dataDecodingStrategy.decodeData(from: &copy)
    }
    
    func decodeUnhintedNumber<V: JSONDecodingVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V, number: JSONPrimitive.Number) throws(CodingError.Decoding) -> V.DecodedValue {
        // Check if the visitor wants arbitrary precision numbers
        if visitor.prefersArbitraryPrecisionNumbers {
            return try visitor.visitArbitraryPrecisionNumber(number.extendedPrecisionRepresentation.utf8Span)
        }
        
        return try decodeUnhintedNumberCommon(visitor, number: number)
    }
    
    func decodeUnhintedNumberCommon<V: DecodingNumberVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V, number: JSONPrimitive.Number) throws(CodingError.Decoding) -> V.DecodedValue {
        do {
            return try number.visit(visitor)
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    public func decodeAny<V: JSONDecodingVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V) throws(CodingError.Decoding) -> V.DecodedValue {
        switch value {
        case .string(let string):
            return try visitor.visitString(string)
        case .number(let number):
            return try decodeUnhintedNumber(visitor, number: number)
        case .null:
            return try visitor.visitNone()
        case .bool(let bool):
            return try visitor.visit(bool)
        case .dictionary(let elements):
            var decoder = try JSONPrimitiveDecoder.StructDecoder(elements: elements, options: self.options, codingPath: self.codingPath, depth: self.depth)
            return try visitor.visit(decoder: &decoder)
        case .array(let array):
            var decoder = try JSONPrimitiveDecoder.ArrayDecoder(array: array, options: self.options, codingPath: self.codingPath, depth: self.depth)
            return try visitor.visit(decoder: &decoder)
        }
    }
    
    public func decodeJSONPrimitive() -> JSONPrimitive {
        self.value
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    public mutating func decode<T: JSONDecodable & CommonDecodable & ~Copyable>(_ type: T.Type) throws(CodingError.Decoding) -> T {
        @_transparent func asJSON<TAsJSON: JSONDecodable & ~Copyable>(_ type: TAsJSON.Type) throws(CodingError.Decoding) -> TAsJSON {
            try decode(TAsJSON.self)
        }
        return try asJSON(type)
    }
    
    public mutating func decode<T: CommonDecodable & ~Copyable>(_ type: T.Type) throws(CodingError.Decoding) -> T {
        // TODO: Uhoh. This doesn't work.
//        // Cover all the types that JSONDecoder supports specially that CommonDecodable does not.
//        if type == Date.self {
//            return _identityCast(try self.decode(Date.self), as: T.Type)
//        }
//        if type == Data.self {
//            return try self.decode(Data.self) as! T
//        }
        if type == URL.self {
            fatalError("TBD")
            // TODO: Should this exist as a separate overload for JSON? Public or internal?
//            return try self.decode(URL.self) as! T
        }
        if type == Decimal.self {
            fatalError("TBD")
            // TODO: Should this exist as a separate overload for JSON? Public or internal?
//            return try self.decode(Decimal.self) as! T
        }
        return try T.decode(from: &self)
    }
    
    @_disfavoredOverload
    public mutating func decode<T: Decodable>(_ t: T.Type) throws(CodingError.Decoding) -> T {
        // JSONPrimitiveDecoder already has a JSONPrimitive, so we can directly create an AdaptorDecoder
        let decoder = AdaptorDecoder(
            value: self.value,
            decoderContext: JSONPrimitive.DecoderContext(
                userInfo: [:], // JSONPrimitiveDecoder doesn't currently track userInfo
                options: self.options
            ),
            codingPath: self.codingPath.toCodingKeys()
        )
        
        do {
            return try T(from: decoder)
        } catch { fatalError("TODO: Wrap/convert error" ) }
    }
}

extension JSONPrimitiveDecoder: CommonDecoder {
    // TODO: Default implementation?
    public mutating func decodeDictionary<T: ~Copyable>(_ closure: (inout StructDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        try decodeStruct(closure)
    }
    
    // TODO: These two methods might require the JSONDecodable & CommonDecodable technique for disambiguation. Also, consider `: Decodable`?
    public mutating func decode<Key: CodingStringKeyRepresentable & Hashable, Value: CommonDecodable>(_: [Key : Value].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Key : Value] {
        guard case let .dictionary(elements) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "dictionary", at: self.codingPath)
        }
        
        let options = self.options
        var decoder = JSONPrimitiveDecoder(value: .null, options: options, codingPath: codingPath.appending(""), depth: self.depth)
        let mapped = try elements.map { pair throws(CodingError.Decoding) in
            decoder.codingPath.replaceLast(with: pair.key)
            decoder.value = pair.value
            return (try Key.codingStringKeyVisitor.visitString(pair.key), try decoder.decode(Value.self))
        }
        return Dictionary(mapped, uniquingKeysWith: { (existing, new) in existing })
    }
    
    public mutating func decode<Element: CommonDecodable>(_: [Element].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Element] {
        guard case let .array(array) = value else {
            throw value.typeMismatchError(expectedTypeDescription: "array", at: self.codingPath)
        }
        
        let options = self.options
        var decoder = JSONPrimitiveDecoder(value: .null, options: options, codingPath: codingPath.appending(index: -1), depth: self.depth)
        return try array.map { el throws(CodingError.Decoding) in
            decoder.codingPath.incrementLast()
            decoder.value = el
            return try decoder.decode(Element.self)
        }
    }
    
    // TODO: Default implementation?
    public var supportsDecodeAny: Bool {
        true
    }
    
    public mutating func decodeAny<V : CommonDecodingVisitor>(_ visitor: V) throws(CodingError.Decoding) -> V.DecodedValue {
        let result: V.DecodedValue
        switch self.value {
        case .string:
            result = try self.decodeString(visitor)
        case .dictionary:
            result = try self.decodeDictionary { dictDecoder throws(CodingError.Decoding) in
                try visitor.visit(decoder: &dictDecoder)
            }
        case .array:
            result = try self.decodeArray { seqDecoder throws(CodingError.Decoding) in
                try visitor.visit(decoder: &seqDecoder)
            }
        case .bool(let bool):
            result = try visitor.visit(bool)
        case .null:
            result = try visitor.visitNone()
        case .number(let number):
            result = try decodeUnhintedNumberCommon(visitor, number: number)
        }
        return result
    }
    
    struct JSONPrimitiveStringByteIterator: JSONByteIterator {
        var iterator: String.UTF8View.Iterator
        
        init(string: String) {
            self.iterator = string.utf8.makeIterator()
        }
        
        mutating func nextByte() -> UInt8? {
            self.iterator.next()
        }
        
        func finish() {}
    }
    
    struct JSONPrimitiveArrayByteIterator: DecodingBytesIterator {
        var iterator: [JSONPrimitive].Iterator
        
        mutating func next() throws(CodingError.Decoding) -> UInt8? {
            guard let nextValue = iterator.next() else {
                return nil
            }
            do {
                return try nextValue.decode(UInt8.self)
            } catch {
                fatalError("TODO: Convert/wrap error")
            }
        }
    }
    
    
    public mutating func decodeBytes<V: DecodingBytesVisitor>(visitor: V) throws(CodingError.Decoding) -> V.DecodedValue {
        do {
            // TODO: Respect data decoding options?
            switch self.value {
            case .string(let string):
                var iterator = JSONBase64ByteIterator(iterator: JSONPrimitiveStringByteIterator(string: string))
                let result = try visitor.visitBytes(&iterator)
                try iterator.finish()
                return result
            case .array(let array):
                var iterator = JSONPrimitiveArrayByteIterator(iterator: array.makeIterator())
                let result = try visitor.visitBytes(&iterator)
                return result
            default:
                throw self.value.typeMismatchError(expectedTypeDescription: "base64 string or byte array", at: self.codingPath)
            }
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    public typealias DictionaryDecoder = StructDecoder
}

public struct JSONIntermediateKeyValueStorage {
    var storage: [(key: String, value: JSONPrimitive)] = .init()
    let options: NewJSONDecoder.Options
    
    internal init(options: NewJSONDecoder.Options) {
        self.options = options
    }
    
    public var isEmpty: Bool { storage.isEmpty }
    
    public mutating func append(_ pair: (key: String, value: JSONPrimitive)) {
        self.storage.append(pair)
    }
}

extension JSONPrimitive {
    @usableFromInline
    func typeMismatchError<T>(expectedType: T.Type, at path: CodingPath) -> CodingError.Decoding {
        switch self {
        case .array(let array): CodingError.typeMismatch(expectedType: expectedType, actualValue: array, at: path)
        case .dictionary(let dict): CodingError.typeMismatch(expectedType: expectedType, actualValue: dict, at: path)
        case .bool(let bool): CodingError.typeMismatch(expectedType: expectedType, actualValue: bool, at: path)
        case .number(let number): CodingError.typeMismatch(expectedTypeDescription: String(describing: expectedType), actualValueDescription: number.extendedPrecisionRepresentation)
        case .string(let string): CodingError.typeMismatch(expectedTypeDescription: String(describing: expectedType), actualValueDescription: "\"\(string)\"")
        case .null: CodingError.typeMismatch(expectedTypeDescription: String(describing: expectedType), actualValueDescription: "null")
        }
    }
    
    @usableFromInline
    func typeMismatchError(expectedTypeDescription: String, at path: CodingPath) -> CodingError.Decoding {
        switch self {
        case .array(let array): CodingError.typeMismatch(expectedTypeDescription: expectedTypeDescription, actualValueDescription: array.description, at: path)
        case .dictionary(let dict): CodingError.typeMismatch(expectedTypeDescription: expectedTypeDescription, actualValueDescription: dict.description, at: path)
        case .bool(let bool): CodingError.typeMismatch(expectedTypeDescription: expectedTypeDescription, actualValueDescription: bool.description, at: path)
        case .number(let number): CodingError.typeMismatch(expectedTypeDescription: expectedTypeDescription, actualValueDescription: number.extendedPrecisionRepresentation)
        case .string(let string): CodingError.typeMismatch(expectedTypeDescription: expectedTypeDescription, actualValueDescription: "\"\(string)\"")
        case .null: CodingError.typeMismatch(expectedTypeDescription: expectedTypeDescription, actualValueDescription: "null")
        }
    }
}
