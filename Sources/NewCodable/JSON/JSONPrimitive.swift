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

public enum JSONPrimitive {
    case string(String)
    case number(Number)
    case bool(Bool)
    case null
    
    case dictionary([(key: String, value: JSONPrimitive)])
    case array([JSONPrimitive])
    
    public struct Number {
        let string: String
        
        public init(extendedPrecisionRepresentation: String) {
            self.string = extendedPrecisionRepresentation
        }
        
        // TODO: Other numeric initializers? Alternative numeric storage?
        
        public subscript<T: FixedWidthInteger>(_ : T.Type) -> T {
            get throws {
                // TODO: We probably need to convert these errors to something else because it will present information like SourceLocation. What even is the type of the error?
                let span = string.utf8Span.span.bytes
                var reader = JSONParserDecoder.ParserState.DocumentReader(bytes: span)
                
                // TODO: Copied from ParserState. Creating one requires faking more than we really need to.
                // TODO: TEST NEGATIVE FLOATS HERE. I think `parseInteger` consumes the `-` and doesn't restore it on returning .retryAsFloatingPoint
                switch try reader.parseInteger(as: T.self) {
                case .pureInteger(let integer):
                    return integer
                case .retryAsFloatingPoint:
                    // TODO: Slowpath? Lots of inlined code here.
                    let double = try reader.parseFloatingPoint(as: Double.self)
                    guard let integer = T(exactly: double) else {
                        fatalError("TODO: Throw error")
                    }

                    // TODO: Classic JSONDecoder would retry Decimal -> integer parsing
                    return integer
                case .notANumber:
                    fatalError("TODO: Throw error")
                }
            }
        }
        public subscript<T: BinaryFloatingPoint>(_ : T.Type) -> T {
            get throws {
                // TODO: Implement better.
                if T.self == Double.self {
                    return Double(string)! as! T
                } else if T.self == Float.self {
                    return Float(string)! as! T
                }
                fatalError()
            }
        }
        
        internal func visit<Visitor: DecodingNumberVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing Visitor) throws(_JSONDecodingError) -> Visitor.DecodedValue {
            // TODO: Consider constraining the visited integer type to the smallest that will fit it. Default visitor implementations would promote back to the largest implemented visitor.

            // TODO: We probably need to convert these errors to something else because it will present information like SourceLocation. What even is the type of the error?
            let span = string.utf8Span.span.bytes
            var reader = JSONParserDecoder.ParserState.DocumentReader(bytes: span)
            
            // TODO: Copied from ParserState. Creating one requires faking more than we really need to.
            // TODO: TEST NEGATIVE FLOATS HERE. I think `parseInteger` consumes the `-` and doesn't restore it on returning .retryAsFloatingPoint
            if self.isNegative {
                if case let .pureInteger(integer) = try reader.parseInteger(as: Int64.self) ^^ .jsonError {
                    return try visitor.visit(integer) ^^ .decodingError
                }
                // fall through to Double
            } else {
                if case let .pureInteger(integer) = try reader.parseInteger(as: UInt64.self) ^^ .jsonError {
                    return try visitor.visit(integer) ^^ .decodingError
                }
            }
            let double = try reader.parseFloatingPoint(as: Double.self) ^^ .jsonError
            return try visitor.visit(double) ^^ .decodingError
        }

        // TODO: Name: `full(Available)PrecisionRepresentation` ? 
        public var extendedPrecisionRepresentation: String {
            string
        }
        
        /*TODO: public? */ var isNegative: Bool {
            guard let first = self.string.utf8.first else {
                return false
            }
            return first == ._minus
        }
    }
}

extension JSONPrimitive: JSONDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeJSONPrimitive()
    }
}

extension JSONPrimitive: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        switch self {
        case .null:
            try encoder.encodeNil()
        case .bool(let bool):
            try encoder.encode(bool)
        case .string(let string):
            try encoder.encode(string)
        case .number(let number):
            // TODO: Figure out the right types here.
            // TODO: watchOS/32-bit
            try encoder.encode(arbitraryPrecisionNumber: number.extendedPrecisionRepresentation.utf8Span)
        case .array(let array):
            try encoder.encodeArray { arrayEncoder throws(CodingError.Encoding) in
                for element in array {
                    try arrayEncoder.encode(element)
                }
            }
        case .dictionary(let dict):
            try encoder.encodeDictionary { dictEncoder throws(CodingError.Encoding) in
                for (key, value) in dict {
                    try dictEncoder.encode(key: key) { elementEncoder throws(CodingError.Encoding) in try elementEncoder.encode(value) }
                }
            }
        }
    }
}

extension JSONPrimitive.Number: Equatable {
    
}

extension JSONPrimitive: Equatable {
    public static func == (lhs: JSONPrimitive, rhs: JSONPrimitive) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): true
        case (.bool(let b1), .bool(let b2)): b1 == b2
        case (.string(let s1), .string(let s2)): s1 == s2
        case (.number(let n1), .number(let n2)): n1 == n2
        case (.array(let a1), .array(let a2)): a1 == a2
        case (.dictionary(let d1), .dictionary(let d2)):
            // TODO: Reconsider what dictionary equality means? Do we require order preservation?
            zip(d1, d2).reduce(true) { (value, next) in
                let keysEqual = next.0.key == next.1.key
                let valuesEqual = next.0.value == next.1.value
                return value && keysEqual && valuesEqual
            }
        default: false
        }
    }
}


// Traditional Codable support

extension JSONPrimitive {
    func decodeNil() -> Bool {
        guard case .null = self else {
            return false
        }
        return true
    }
    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .bool(let value) = self else {
            fatalError("ERROR")
        }
        return value
    }
    func decode(_ type: String.Type) throws -> String {
        guard case .string(let value) = self else {
            fatalError("ERROR")
        }
        return value
    }
    func decode(_ type: Double.Type) throws -> Double {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        return try number[type]
    }
    func decode(_ type: Float.Type) throws -> Float {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let double = try number[Double.self]
        guard let float = Float(exactly: double) else {
            fatalError("ERROR")
        }
        return float
    }
    func decode(_ type: Int.Type) throws -> Int {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let i64 = try number[Int64.self]
        guard let result = Int(exactly: i64) else {
            fatalError("ERROR")
        }
        return result
    }
    func decode(_ type: Int8.Type) throws -> Int8 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let i64 = try number[Int64.self]
        guard let result = Int8(exactly: i64) else {
            fatalError("ERROR")
        }
        return result
    }
    func decode(_ type: Int16.Type) throws -> Int16 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let i64 = try number[Int64.self]
        guard let result = Int16(exactly: i64) else {
            fatalError("ERROR")
        }
        return result
    }
    func decode(_ type: Int32.Type) throws -> Int32 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let i64 = try number[Int64.self]
        guard let result = Int32(exactly: i64) else {
            fatalError("ERROR")
        }
        return result
    }
    func decode(_ type: Int64.Type) throws -> Int64 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        return try number[type]
    }
    func decode(_ type: Int128.Type) throws -> Int128 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        return try number[type]
    }
    func decode(_ type: UInt.Type) throws -> UInt {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let u64 = try number[UInt64.self]
        guard let result = UInt(exactly: u64) else {
            fatalError("ERROR")
        }
        return result
    }
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let u64 = try number[UInt64.self]
        guard let result = UInt8(exactly: u64) else {
            fatalError("ERROR")
        }
        return result}
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let u64 = try number[UInt64.self]
        guard let result = UInt16(exactly: u64) else {
            fatalError("ERROR")
        }
        return result
    }
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        let u64 = try number[UInt64.self]
        guard let result = UInt32(exactly: u64) else {
            fatalError("ERROR")
        }
        return result}
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        return try number[type]
    }
    func decode(_ type: UInt128.Type) throws -> UInt128 {
        guard case .number(let number) = self else {
            fatalError("ERROR")
        }
        return try number[type]
    }
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = _JSONValueDecoder(self)
        return try type.init(from: decoder)
    }
}

internal class _JSONValueDecoder {
    let value: JSONPrimitive
    init(_ value: JSONPrimitive) {
        self.value = value
    }
}

extension _JSONValueDecoder: Decoder {
    // TODO: Need to pass down decoding strategies.
    // TODO: Coding Paths
    // TODO: Line number information???
    var codingPath: [any CodingKey] {
        // TODO
        []
    }
    
    var userInfo: [CodingUserInfoKey : Any] {
        [:]
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        switch value {
        case let .dictionary(elements):
            let container = KeyedContainer<Key>(
                dict: Dictionary(elements, uniquingKeysWith: { (existing, new) in existing })
            )
            return KeyedDecodingContainer(container)
        case .null:
            throw DecodingError.valueNotFound([String:Any].self, .init(codingPath: [], debugDescription: "Cannot get keyed decoding container -- found null value instead"))
        default:
            throw DecodingError.typeMismatch([String:Any].self, .init(codingPath: [], debugDescription: "Expected to decode \([String:Any].self) but found TODO"))
        }
    }
    
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        switch value {
        case let .array(array):
            return UnkeyedContainer(
                array: array
            )
        case .null:
            throw DecodingError.valueNotFound([String:Any].self, .init(codingPath: [], debugDescription: "Cannot get keyed decoding container -- found null value instead"))
        default:
            throw DecodingError.typeMismatch([String:Any].self, .init(codingPath: [], debugDescription: "Expected to decode \([String:Any].self) but found TODO"))
        }
    }
    
    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        self
    }
}

extension _JSONValueDecoder {
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let dict: [String:JSONPrimitive]
        
        // TODO: CodingPath
        public var codingPath: [any CodingKey] {
            []
        }
        
        public var allKeys: [Key] {
            self.dict.keys.compactMap { Key(stringValue: $0) }
        }
        
        func contains(_ key: Key) -> Bool {
            dict.keys.contains(key.stringValue)
        }
        
        internal func getValue(forKey key: Key) throws -> JSONPrimitive {
            guard let value = dict[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: [], debugDescription: "No value assicated with key \(key) (\"\(key.stringValue)\")"))
            }
            return value
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            try getValue(forKey: key).decodeNil()
        }
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
            try getValue(forKey: key).decode(type)
        }
        func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
            try getValue(forKey: key).decode(type)
        }
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            try getValue(forKey: key).decode(type)
        }
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            let value = try getValue(forKey: key)
            return try _JSONValueDecoder(value).container(keyedBy: type)
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            let value = try getValue(forKey: key)
            return try _JSONValueDecoder(value).unkeyedContainer()
        }
        
        func superDecoder() throws -> any Decoder {
            fatalError("TODO")
        }
        
        func superDecoder(forKey key: Key) throws -> any Decoder {
            fatalError("TODO")
        }
    }
}

extension _JSONValueDecoder {
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        var valueIterator: [JSONPrimitive].Iterator
        var peekedValue: JSONPrimitive?
        let count: Int?

        var isAtEnd: Bool { self.currentIndex >= (self.count!) }
        var currentIndex = 0

        init(array: [JSONPrimitive]) {
            self.valueIterator = array.makeIterator()
            self.count = array.count
        }

        public var codingPath: [CodingKey] {
            // TODO:
            []
        }

        @inline(__always)
        var currentIndexKey : _CodingKey {
            .init(index: currentIndex)
        }

        @inline(__always)
        var currentCodingPath: [CodingKey] {
            []
        }

        private mutating func advanceToNextValue() {
            currentIndex += 1
            peekedValue = nil
        }

        mutating func decodeNil() throws -> Bool {
            let value = try self.peekNextValue(ofType: Never.self)
            switch value {
            case .null:
                advanceToNextValue()
                return true
            default:
                // The protocol states:
                //   If the value is not null, does not increment currentIndex.
                return false
            }
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let value = try self.peekNextValue(ofType: Bool.self)
            guard case .bool(let bool) = value else {
                fatalError("TODO")
//                throw impl.createTypeMismatchError(type: type, for: self.currentCodingPath, value: value)
            }

            advanceToNextValue()
            return bool
        }

        mutating func decode(_ type: String.Type) throws -> String {
            let value = try self.peekNextValue(ofType: String.self)
            let string = try value.decode(String.self)
            advanceToNextValue()
            return string
        }

        mutating func decode(_ type: Double.Type) throws -> Double {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: Float.Type) throws -> Float {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: Int.Type) throws -> Int {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }
      
//        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_ type: Int128.Type) throws -> Int128 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: UInt.Type) throws -> UInt {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }
      
//        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)
            advanceToNextValue()
            return result
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            let value = try self.peekNextValue(ofType: type)
            let result = try value.decode(type)

            advanceToNextValue()
            return result
        }

        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            let value = try self.peekNextValue(ofType: KeyedDecodingContainer<NestedKey>.self)
            let container = try _JSONValueDecoder(value).container(keyedBy: type)

            advanceToNextValue()
            return container
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let value = try self.peekNextValue(ofType: UnkeyedDecodingContainer.self)
            let container = try _JSONValueDecoder(value).unkeyedContainer()

            advanceToNextValue()
            return container
        }

        mutating func superDecoder() throws -> Decoder {
            let decoder = try decoderForNextElement(ofType: Decoder.self)
            advanceToNextValue()
            return decoder
        }

        private mutating func decoderForNextElement<T>(ofType type: T.Type) throws -> _JSONValueDecoder {
            let value = try self.peekNextValue(ofType: type)
            let decoder = _JSONValueDecoder(value)
            return decoder
        }

        @inline(__always)
        private mutating func peekNextValue<T>(ofType type: T.Type) throws -> JSONPrimitive {
            if let value = peekedValue {
                return value
            }
            guard let nextValue = valueIterator.next() else {
                var message = "Unkeyed container is at end."
                if T.self == UnkeyedContainer.self {
                    message = "Cannot get nested unkeyed container -- unkeyed container is at end."
                }
                if T.self == Decoder.self {
                    message = "Cannot get superDecoder() -- unkeyed container is at end."
                }

                var path = self.codingPath
                path.append(_CodingKey(index: self.currentIndex))

                throw DecodingError.valueNotFound(
                    type,
                    .init(codingPath: path,
                          debugDescription: message,
                          underlyingError: nil))
            }
            peekedValue = nextValue
            return nextValue
        }
    }

}

extension _JSONValueDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool { value.decodeNil() }
    func decode(_ type: Bool.Type) throws -> Bool { try value.decode(type) }
    func decode(_ type: String.Type) throws -> String { try value.decode(type) }
    func decode(_ type: Double.Type) throws -> Double { try value.decode(type) }
    func decode(_ type: Float.Type) throws -> Float { try value.decode(type) }
    func decode(_ type: Int.Type) throws -> Int { try value.decode(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try value.decode(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try value.decode(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try value.decode(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try value.decode(type) }
    func decode(_ type: Int128.Type) throws -> Int128 { try value.decode(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try value.decode(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try value.decode(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try value.decode(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try value.decode(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try value.decode(type) }
    func decode(_ type: UInt128.Type) throws -> UInt128 { try value.decode(type) }
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable { try value.decode(type) }
}


// Adaptor Coding

extension JSONPrimitive: AdaptableDecodableValue {
    public struct DecoderContext: AdaptorDecoderContext {
        public let userInfo: [CodingUserInfoKey : Any]
        public let options: NewJSONDecoder.Options
    }
    
    public typealias ArrayIterator = [JSONPrimitive].Iterator
    
    public func decodeNil(context: AdaptorDecodableValueContext<JSONPrimitive>) -> Bool {
        guard case .null = self else {
            return false
        }
        return true
    }
    
    public func decode(_ type: Bool.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Bool {
        guard case let .bool(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return value
    }
    
    public func decode(_ type: String.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> String {
        guard case let .string(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return value
    }
    
    public func decode(_ type: Double.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Double {
        switch self {
        case .number(let value):
            return try value[type]
        case .string(let stringValue):
            if case let .convertFromString(positiveInfinity, negativeInfinity, nan) = context.decoderContext.options.nonConformingFloatDecodingStrategy {
                switch stringValue {
                case positiveInfinity: return .infinity
                case negativeInfinity: return -.infinity
                case nan: return .nan
                default: break
                }
            }
            fallthrough // to type error
        default:
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
    }
    
    public func decode(_ type: Float.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Float {
        switch self {
        case .number(let value):
            return try value[type]
        case .string(let stringValue):
            if case let .convertFromString(positiveInfinity, negativeInfinity, nan) = context.decoderContext.options.nonConformingFloatDecodingStrategy {
                switch stringValue {
                case positiveInfinity: return .infinity
                case negativeInfinity: return -.infinity
                case nan: return .nan
                default: break
                }
            }
            fallthrough // to type error
        default:
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
    }
    
    public func decode(_ type: Int.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Int {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: Int8.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Int8 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: Int16.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Int16 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: Int32.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Int32 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: Int64.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Int64 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: Int128.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> Int128 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: UInt.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> UInt {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: UInt8.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> UInt8 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: UInt16.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> UInt16 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: UInt32.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> UInt32 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: UInt64.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> UInt64 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode(_ type: UInt128.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> UInt128 {
        guard case let .number(value) = self else {
            // TODO: Type descriptions aren't great.
            throw DecodingError.typeMismatch(type, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \(type) but found \(self) instead."
            ))
        }
        return try value[type]
    }
    
    public func decode<T>(_ type: T.Type, context: AdaptorDecodableValueContext<JSONPrimitive>) throws -> T where T : Decodable {
        return try context.withDecoder(for: self) {
            try type.init(from: $0)
        }
    }
    
    public func makeDictionary(context: AdaptorDecodableValueContext<Self>) throws -> [String : JSONPrimitive] {
        guard case let .dictionary(elements) = self else {
            throw DecodingError.typeMismatch([String:JSONPrimitive].self, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \([String:JSONPrimitive].self) but found \(self) instead."
            ))
        }
        return Dictionary(elements, uniquingKeysWith: { (existing, new) in existing })
    }
    
    public func makeArrayIterator(context: AdaptorDecodableValueContext<Self>) throws -> (Array<JSONPrimitive>.Iterator, countHint: Int?) {
        guard case let .array(array) = self else {
            throw DecodingError.typeMismatch([JSONPrimitive].self, .init(
                codingPath: context.codingPath,
                debugDescription: "Expected to decode \([JSONPrimitive].self) but found \(self) instead."
            ))
        }
        return (array.makeIterator(), array.count)
    }
}

extension JSONPrimitive: AdaptorEncodableValue {
    public struct EncoderContext: AdaptorEncoderContext {
        public let userInfo: [CodingUserInfoKey : Any]
        
        public let options: NewJSONEncoder.Options
    }
    
    public init(_ value: Bool, context: AdaptorEncodableValueContext<Self>) { self = .bool(value) }
    public init(_ value: String, context: AdaptorEncodableValueContext<Self>) { self = .string(value) }
    // TODO: Not quite.
    @inline(__always)
    private init<T: BinaryFloatingPoint & CustomStringConvertible>(floatingPoint value: T, context: AdaptorEncodableValueContext<Self>) throws {
        if let string = try context.encoderContext.options.nonConformingFloatEncodingStrategy.handleNonConformingFloat(value) {
            self = .string(string)
        } else {
            var description = value.description
            if description.hasSuffix(".0") {
                description.removeLast(2)
            }
            self = .number(.init(extendedPrecisionRepresentation: description))
        }
    }
    public init(_ value: Double, context: AdaptorEncodableValueContext<Self>) throws { try self.init(floatingPoint: value, context: context) }
    public init(_ value: Float, context: AdaptorEncodableValueContext<Self>) throws { try self.init(floatingPoint: value, context: context) }
    public init(_ value: Int, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: Int8, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: Int16, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: Int32, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: Int64, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: Int128, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: UInt, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: UInt8, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: UInt16, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: UInt32, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: UInt64, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    public init(_ value: UInt128, context: AdaptorEncodableValueContext<Self>) { self = .number(.init(extendedPrecisionRepresentation: value.description)) }
    
    public init(_ array: [JSONPrimitive]) {
        self = .array(array)
    }
    
    public init(_ dict: [String : JSONPrimitive]) {
        self = .dictionary(Array(dict))
    }
    
    public init<T: Encodable>(from value: T, context: AdaptorEncodableValueContext<Self>) throws {
        self = try context.withEncoder {
            try value.encode(to: $0)
            return $0.encodedValue
        }
    }
    
    public var array: [JSONPrimitive]? {
        guard case .array(let array) = self else {
            return nil
        }
        return array
    }
    
    public var dictionary: [String : JSONPrimitive]? {
        guard case .dictionary(let elements) = self else {
            return nil
        }
        return Dictionary(elements, uniquingKeysWith: { (existing, new) in existing })
    }
    
    
}

