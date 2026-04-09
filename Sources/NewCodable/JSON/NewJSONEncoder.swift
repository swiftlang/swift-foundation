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

// TODO: Sorting
// TODO: Pretty

public struct NewJSONEncoder {
    public struct Options {
        
        /// The strategy to use for encoding `Date` values.
        public struct DateEncodingStrategy : Sendable {
            internal enum _Storage: @unchecked Sendable {
                case deferredToDate
                case secondsSince1970
                case millisecondsSince1970
                case iso8601
                case formatted(any FormatStyle<Date,String>)
            }
            internal let storage: _Storage
            
            // TODO: Change this to secondsSinceReferenceDate?
            /// Defer to `Date` for encoding. This is the default strategy.
            public static var deferredToDate: Self {
                .init(storage: .deferredToDate)
            }
            
            /// Encode the `Date` as a UNIX timestamp from a JSON number.
            public static var secondsSince1970: Self {
                .init(storage: .secondsSince1970)
            }
            
            /// Encode the `Date` as UNIX millisecond timestamp from a JSON number.
            public static var millisecondsSince1970: Self {
                .init(storage: .millisecondsSince1970)
            }
            
            /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
            public static var iso8601: Self {
                .init(storage: .iso8601)
            }
            
            /// Encode the `Date` as a string formatted by the given format.
            public static func formatted(_ style: some FormatStyle<Date,String> & Sendable) -> Self {
                .init(storage: .formatted(style))
            }
        }
        
        /// The strategy to use for encoding `Data` values.
        public enum DataEncodingStrategy : Sendable {
            
            /// Defer to `Data` for encoding.
            case deferredToData
            
            /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
            case base64
        }
        
        /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
        public enum NonConformingFloatEncodingStrategy : Sendable {
            /// Throw upon encountering non-conforming values. This is the default strategy.
            case `throw`
            
            /// Encode the values using the given representation strings.
            case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
            
            private func _positiveInfinityOrThrow() throws(CodingError.Encoding) -> String {
                // TODO: How to add codingPath?
                switch self {
                case .throw: throw CodingError.invalidEncodedValue(valueDescription: "infinity")
                case .convertToString(let positiveInfinity, _, _):
                    return positiveInfinity
                }
            }
            
            private func _negativeInfinityOrThrow() throws(CodingError.Encoding) -> String {
                // TODO: How to add codingPath?
                switch self {
                case .throw: throw CodingError.invalidEncodedValue(valueDescription: "-infinity")
                case .convertToString(_, let negativeInfinity, _):
                    return negativeInfinity
                }
            }
            
            private func _nanOrThrow() throws(CodingError.Encoding) -> String {
                // TODO: How to add codingPath?
                switch self {
                case .throw: throw CodingError.invalidEncodedValue(valueDescription: "NaN")
                case .convertToString(_, _, let nan):
                    return nan
                }
            }
            
            @inline(__always)
            internal func handleNonConformingFloat<T: BinaryFloatingPoint>(_ value: T) throws(CodingError.Encoding) -> String? {
                switch value {
                case T.infinity:
                    return try _positiveInfinityOrThrow()
                case -T.infinity:
                    return try _negativeInfinityOrThrow()
                default:
                    if value.isNaN {
                        return try _nanOrThrow()
                    }
                    return nil
                }
            }
        }
        
        var assumesTopLevelDictionary = false // TODO: Unimplemented
        internal var dataEncodingStrategy: DataEncodingStrategy
        internal var dateEncodingStrategy: DateEncodingStrategy
        internal var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy
        internal var withoutEscapingSlashes: Bool
        internal var pretty: Bool
        
        public init(assumesTopLevelDictionary: Bool = false,
                    dataEncodingStrategy: DataEncodingStrategy = .base64,
                    dateEncodingStrategy: DateEncodingStrategy = .deferredToDate,
                    nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw,
                    withoutEscapingSlashes: Bool = false,
                    pretty: Bool = false
        ) {
            self.assumesTopLevelDictionary = assumesTopLevelDictionary
            self.dataEncodingStrategy = dataEncodingStrategy
            self.dateEncodingStrategy = dateEncodingStrategy
            self.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
            self.withoutEscapingSlashes = withoutEscapingSlashes
            self.pretty = pretty
        }
    }
    
    let options: Options
    
    public init(options: Options = .init()) {
        self.options = options
    }
    
    internal func encode(_ value: borrowing some JSONEncodable & ~Copyable) throws(CodingError.Encoding) -> GrowableEncodingBytes {
        var rootNodeArray: InlineArray = [JSONDirectEncoder.CodingPathNode.root]
        var nodeSpan = rootNodeArray.mutableSpan
        return try nodeSpan.withUnsafeMutableBufferPointer { ptr throws(CodingError.Encoding) in
            var inner = JSONDirectEncoder(options: self.options, topCodingPathNode: ptr.baseAddress!)
            try value.encode(to: &inner)
            return inner.takeBytes()
        }
    }
    
    internal func encode(_ value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) -> GrowableEncodingBytes {
        var rootNodeArray: InlineArray = [JSONDirectEncoder.CodingPathNode.root]
        var nodeSpan = rootNodeArray.mutableSpan
        return try nodeSpan.withUnsafeMutableBufferPointer { ptr throws(CodingError.Encoding) in
            var inner = JSONDirectEncoder(options: self.options, topCodingPathNode: ptr.baseAddress!)
            try value.encode(to: &inner)
            return inner.takeBytes()
        }
    }
    
    // TODO: Replace with a more desirable span-based interface 
    public func encode<T: ~Copyable>(_ value: borrowing some JSONEncodable & ~Copyable, _ resultSpanClosure: (RawSpan) throws -> T) throws -> T {
        let bytes: GrowableEncodingBytes = try self.encode(value)
        return try resultSpanClosure(bytes.span.bytes)
    }
    
    public func encode<T: ~Copyable>(_ value: borrowing some JSONEncodable & CommonEncodable & ~Copyable, _ resultSpanClosure: (RawSpan) throws -> T) throws -> T {
        @_transparent func asJSON<TAsJSON: JSONEncodable & ~Copyable>(_ value: borrowing TAsJSON) throws -> T {
            try self.encode(value, resultSpanClosure)
        }
        return try asJSON(value)
    }
    
    public func encode<T: ~Copyable>(_ value: borrowing some CommonEncodable & ~Copyable, _ resultSpanClosure: (RawSpan) throws -> T) throws -> T {
        let bytes: GrowableEncodingBytes = try self.encode(value)
        return try resultSpanClosure(bytes.span.bytes)
    }
}

// TODO: Move to Foundation + JSON cross-module import.
extension NewJSONEncoder {
    public func encode(_ value: borrowing some JSONEncodable & ~Copyable) throws(CodingError.Encoding) -> Data {
        let bytes: GrowableEncodingBytes = try self.encode(value)
        
        let (storage, count) = bytes.deconstruct()
        guard let pointer = storage.baseAddress else { return Data() }
        return Data(bytesNoCopy: pointer, count: count, deallocator: .custom({ptr, _ in ptr.deallocate() }))
    }
    
    public func encode(_ value: borrowing some JSONEncodable & CommonEncodable & ~Copyable) throws(CodingError.Encoding) -> Data {
        @_transparent func asJSON<TAsJSON: JSONEncodable & ~Copyable>(_ value: borrowing TAsJSON) throws(CodingError.Encoding) -> Data {
            try self.encode(value)
        }
        return try asJSON(value)
    }
    
    public func encode(_ value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) -> Data {
        let bytes: GrowableEncodingBytes = try self.encode(value)
        
        let (storage, count) = bytes.deconstruct()
        guard let pointer = storage.baseAddress else { return Data() }
        return Data(bytesNoCopy: pointer, count: count, deallocator: .custom({ptr, _ in ptr.deallocate() }))
    }
}

extension UnsafeMutablePointer<JSONDirectEncoder.CodingPathNode> {
    mutating func unwindToParent() {
        switch self.pointee {
        case .root: fatalError("Can't unwind coding path past root")
        case .array(_, parent: let ptr): self = ptr
        case .dictionary(_, parent: let ptr): self = ptr
        }
    }
}

public struct JSONDirectEncoder: CommonEncoder, ~Copyable, ~Escapable {
    enum CodingPathNode {
        case root
        case array(Int, parent: UnsafeMutablePointer<CodingPathNode>)
        // TODO: If/when we can make CodingPathNode: ~Escapable, I believe we can have `.dictionary` contain a `String` instead of a UTF8Span, which will avoid the cost of BOTH retain/release AND `.utf8Span`.
        case dictionary(UnsafeBufferPointer<UInt8>, parent: UnsafeMutablePointer<CodingPathNode>)
        
        @usableFromInline
        @inline(__always)
        static func newDictionaryNode(withParent parent: UnsafeMutablePointer<CodingPathNode>) -> Self {
            .dictionary(UnsafeBufferPointer(_empty: ()), parent: parent)
        }
        
        @usableFromInline
        @inline(__always)
        static func newArrayNode(withParent parent: UnsafeMutablePointer<CodingPathNode>) -> Self {
            .array(-1, parent: parent)
        }

        @inline(__always)
        mutating func setDictionaryKey(_ key: UTF8Span) {
            guard case .dictionary(_, let parent) = self else {
                preconditionFailure("Wrong node type")
            }
            key.span.withUnsafeBufferPointer {
                self = .dictionary($0, parent: parent)
            }
        }

        @inline(__always)
        mutating func incrementArrayIndex() {
            guard case .array(let idx, let parent) = self else {
                preconditionFailure("Wrong node type")
            }
            self = .array(idx + 1, parent: parent)
        }

        func printCodingPathAddrs() {
            switch self {
            case .root:
                print("root")
            case .array(_, let parent):
                parent.pointee.printCodingPathAddrs()
                print("array:", parent)
            case .dictionary(_, let parent):
                parent.pointee.printCodingPathAddrs()
                print("dict:", parent)
            }
        }
        
        var pathComponents: [CodingPath.Component] {
            switch self {
            case .root: return []
            case .dictionary(let buffer, let parentPtr):
                // TODO: Actually parse the JSON
                var components = parentPtr.pointee.pathComponents
                if buffer.baseAddress != nil {
                    components.append(.stringKey(String._tryFromUTF8(buffer)!))
                }
                return components
            case .array(let index, let parentPtr):
                var components = parentPtr.pointee.pathComponents
                if index != -1 {
                    components.append(.index(index))
                }
                return components
            }
        }
        
        var path: CodingPath {
            .init(self.pathComponents)
        }
    }

    typealias Options = NewJSONEncoder.Options

    private var state: State
    
    @_lifetime(immortal)
    internal init(options: Options, topCodingPathNode: UnsafeMutablePointer<CodingPathNode>) {
        let writer = JSONWriter(pretty: options.pretty, withoutEscapingSlashes: options.withoutEscapingSlashes)
        self.state = State(writer: writer, options: options, depth: 0, topCodingPathNode: topCodingPathNode)
    }
    
    @_lifetime(copy state)
    internal init(state: consuming State) {
        self.state = state
    }
    
    public var codingPath: CodingPath {
        state.currentTopCodingPathNode.pointee.path
    }

    public func printCodingPathAddrs() {
        self.state.currentTopCodingPathNode.pointee.printCodingPathAddrs()
    }
    
    consuming func takeBytes() -> GrowableEncodingBytes {
        return self.state.writer.data
    }
    
    public mutating func encodeNil() throws(CodingError.Encoding) {
        state.writer.write("null")
    }
    
    @_lifetime(self: copy self)
    public mutating func encode(_ bool: Bool) throws(CodingError.Encoding) {
        if bool {
            state.writer.write("true")
        } else {
            state.writer.write("false")
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Int) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Int8) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Int16) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Int32) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Int64) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Int128) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: UInt) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: UInt8) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: UInt16) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: UInt32) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: UInt64) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    @_lifetime(self: copy self)
    public mutating func encode(_ value: UInt128) throws(CodingError.Encoding) {
        value.withDecimalDescriptionSpan { self.state.writer.serializeSimpleStringContentsSpan($0) }
    }
    
    @inline(__always)
    @_lifetime(self: copy self)
    private mutating func encodeFloat<T: BinaryFloatingPoint & CustomStringConvertible>(_ value: T) throws(CodingError.Encoding) {
        if let string = try state.options.nonConformingFloatEncodingStrategy.handleNonConformingFloat(value) {
            self.state.writer.serializeString(string, checkForEscapes: false)
        } else {
            var description = value.description
            if description.hasSuffix(".0") {
                description.removeLast(2)
            }
            self.state.writer.serializeSimpleStringContents(description)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Float) throws(CodingError.Encoding) {
        try encodeFloat(value)
    }
    
    @_lifetime(self: copy self)
    public mutating func encode(_ value: Double) throws(CodingError.Encoding) {
        try encodeFloat(value)
    }
    @_lifetime(self: copy self)
    public mutating func encode(arbitraryPrecisionNumber: UTF8Span) throws(CodingError.Encoding) {
        self.state.writer.serializeSimpleStringContentsSpan(arbitraryPrecisionNumber)
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeString(_ string: String) throws(CodingError.Encoding) {
        state.writer.serializeString(string, checkForEscapes: true)
    }
    @_lifetime(self: copy self)
    public mutating func encodeString(_ span: UTF8Span) throws(CodingError.Encoding) {
        state.writer.serializeStringSpan(span, checkForEscapes: true)
    }
    
    @_lifetime(self: copy self)
    internal mutating func encodeAsBase64String(_ span: RawSpan) throws(CodingError.Encoding) {
        // Inefficient.
        let str = Data(_copying: span).base64EncodedString()
        try self.encode(str)
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeBytes(_ span: RawSpan) throws(CodingError.Encoding) {
        if self.state.options.dataEncodingStrategy == .base64 {
            return try encodeAsBase64String(span)
        }
        
        do {
            try state.writer.prepareForArray(depth: state.depth)
        } catch {
            throw error.at(self.codingPath, encodingValueDescription: "bytes")
        }
        
        state.depth &+= 1
        defer {
            state.depth &-= 1
            state.writer.finishArray()
        }
        
        try span.withUnsafeBytes { bytes throws(CodingError.Encoding) in
            var byteIter = bytes.makeIterator()
            guard let first = byteIter.next() else {
                return
            }
            
            state.writer.prepareForArrayElement(first: true)
            try self.encode(first)
            
            while let byte = byteIter.next() {
                state.writer.prepareForArrayElement(first: false)
                try self.encode(byte)
            }
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeBytes(_ bytes: [UInt8]) throws(CodingError.Encoding) {
        try self.encodeBytes(bytes.span.bytes)
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeDictionary(_ closure: (inout DictionaryEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        do {
            try state.writer.prepareForObject(depth: state.depth)
        } catch {
            throw error.at(self.codingPath, encodingValueDescription: "dictionary")
        }

        var dictionaryNode: InlineArray = [
            CodingPathNode.dictionary(UnsafeBufferPointer(_empty: ()), parent: state.currentTopCodingPathNode)
        ]
        var nodeSpan = dictionaryNode.mutableSpan
        state.currentTopCodingPathNode = nodeSpan.withUnsafeMutableBufferPointer {
            $0.baseAddress!
        }

        state.depth += 1
        var encoder = DictionaryEncoder(wrappingEncoder: self)
        
        do {
            try closure(&encoder)
        } catch {
            self = encoder.takeEncoder()
            state.depth -= 1
            
            withExtendedLifetime(nodeSpan) {
                state.currentTopCodingPathNode.unwindToParent()
            }
            
            throw error
        }
        
        self = encoder.takeEncoder()
        state.depth -= 1
        self.state.writer.finishObject()
        
        withExtendedLifetime(nodeSpan) {
            state.currentTopCodingPathNode.unwindToParent()
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeArray(_ closure: (inout ArrayEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        do {
            try state.writer.prepareForArray(depth: state.depth)
        } catch {
            throw error.at(self.codingPath, encodingValueDescription: "array")
        }
        
        var arrayNode: InlineArray = [
            CodingPathNode.array(-1, parent: state.currentTopCodingPathNode)
        ]
        var nodeSpan = arrayNode.mutableSpan
        state.currentTopCodingPathNode = nodeSpan.withUnsafeMutableBufferPointer {
            $0.baseAddress!
        }
        
        state.depth += 1
        var encoder = ArrayEncoder(wrappingEncoder: self)
        
        do {
            try closure(&encoder)
        } catch {
            self = encoder.takeEncoder()
            state.depth -= 1
            
            withExtendedLifetime(nodeSpan) {
                state.currentTopCodingPathNode.unwindToParent()
            }
            
            throw error
        }
        
        self = encoder.takeEncoder()
        state.depth -= 1
        self.state.writer.finishArray()
        
        withExtendedLifetime(nodeSpan) {
            state.currentTopCodingPathNode.unwindToParent()
        }
    }
    
    // Overload for enums with no associated values.
    @_lifetime(self: copy self)
    public mutating func encodeEnumCase(_ name: UTF8Span) throws(CodingError.Encoding) {
        do {
            try state.writer.prepareForObject(depth: state.depth)
        } catch {
            throw error.at(self.codingPath, encodingValueDescription: "enum case named \(String(copying: name))")
        }
        state.depth += 1
        state.writer.prepareForObjectKey(first: true)
        state.writer.serializeStringSpan(name, checkForEscapes: true) // TODO: Make this parameterizable.
        state.writer.prepareForObjectValue()
        do {
            try state.writer.prepareForObject(depth: state.depth)
        } catch {
            state.depth -= 1
            throw error.at(self.codingPath, encodingValueDescription: "associated values for enum case named \(String(copying: name))")
        }
        state.writer.finishObject()
        state.depth -= 1
        state.writer.finishObject()
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeEnumCase(_ name: UTF8Span, associatedValueCount: Int, _ associatedValueClosure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        do {
            try state.writer.prepareForObject(depth: state.depth)
        } catch {
            throw error.at(self.codingPath, encodingValueDescription: "enum case named \(String(copying: name))")
        }
        state.depth += 1
        state.writer.prepareForObjectKey(first: true)
        state.writer.serializeStringSpan(name, checkForEscapes: true) // TODO: Make this parameterizable.
        
        state.writer.prepareForObjectValue()
        
        // Note: encodeStructFields will handle its own depth increment/decrement
        try self.encodeStructFields(count: associatedValueCount, associatedValueClosure)
        
        state.depth -= 1
        state.writer.finishObject()
    }
    
    // TODO: inlinable?
    @_lifetime(self: copy self)
    public mutating func encode<Key: CodingStringKeyRepresentable, Value: JSONEncodable>(_ dictionary: [Key:Value]) throws(CodingError.Encoding) -> Void {
        try encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            for (key, value) in dictionary {
                try key.withCodingStringUTF8Span { utf8Span throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: utf8Span, value: value)
                }
            }
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func encode<Key: CodingStringKeyRepresentable, Value: JSONEncodable & CommonEncodable>(_ dictionary: [Key:Value]) throws(CodingError.Encoding) -> Void {
        try encodeDictionary { dictEncoder throws(CodingError.Encoding) in
            for (key, value) in dictionary {
                try key.withCodingStringUTF8Span { utf8Span throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: utf8Span) { valueEncoder throws(CodingError.Encoding) in
                        @_transparent func asJSON<TAsJSON: JSONEncodable & ~Copyable>(_ jsonValue: borrowing TAsJSON) throws(CodingError.Encoding) {
                            try valueEncoder.encode(jsonValue)
                        }
                        try asJSON(value)
                    }
                }
            }
        }
    }
}

// Special cases
extension JSONDirectEncoder {
    @_lifetime(self: copy self)
    public mutating func encode(_ data: Data) throws(CodingError.Encoding) {
        try encodeBytes(data.bytes)
    }
    
    @_lifetime(self: copy self)
    public mutating func encode(_ date: Date) throws(CodingError.Encoding) {
        try state.options.dateEncodingStrategy.encode(date: date, to: &self)
    }
    
    @_lifetime(self: copy self)
    public mutating func encode(_ url: URL) throws(CodingError.Encoding) {
        // Encode URLs as single strings.
        try self.encode(url.absoluteString)
    }
    
    @_lifetime(self: copy self)
    public mutating func encode(_ decimal: Decimal) throws(CodingError.Encoding) {
        // TODO: watchOS/32-bit
        try self.encode(arbitraryPrecisionNumber: decimal.description.utf8Span)
    }
    
    @_lifetime(self: copy self)
    internal mutating func encodeGenericNonCopyable<T: CommonEncodable & ~Copyable>(_ value: borrowing T) throws(CodingError.Encoding) {
        try value.encode(to: &self)
    }
    
    @_lifetime(self: copy self)
    internal mutating func encodeGeneric<T: CommonEncodable>(_ value: T) throws(CodingError.Encoding) {
        if let date = value as? Date {
            try self.encode(date)
        } else if self.state.options.dataEncodingStrategy == .base64, let data = value as? Data {
            try self.encode(data)
        } else if let url = value as? URL {
            try self.encode(url)
        } else if let decimal = value as? Decimal {
            try self.encode(decimal)
        } else {
            try self.encodeGenericNonCopyable(value)
        }
    }
}
    
extension JSONDirectEncoder {
    struct State: ~Copyable, ~Escapable {
        let options: Options
        var writer: JSONWriter
        var depth: Int
        var currentTopCodingPathNode: UnsafeMutablePointer<CodingPathNode>
        
        @_lifetime(copy writer)
        init(writer: consuming JSONWriter, options: Options, depth: Int, topCodingPathNode: UnsafeMutablePointer<CodingPathNode>) {
            self.writer = writer
            self.options = options
            self.depth = depth
            self.currentTopCodingPathNode = topCodingPathNode
        }
    }
}

extension JSONDirectEncoder {
    public struct DictionaryEncoder: CommonDictionaryEncoder, CommonStructEncoder, ~Copyable, ~Escapable {
        public typealias KeyEncoder = DictionaryKeyEncoder
        public typealias ValueEncoder = JSONDirectEncoder
        
        var innerEncoder: JSONDirectEncoder
        var encodedFirstKey: Bool = false
        
        @_lifetime(copy wrappingEncoder)
        init(wrappingEncoder: consuming JSONDirectEncoder) {
            self.innerEncoder = wrappingEncoder
        }
        
        @_lifetime(copy self)
        consuming func takeEncoder() -> JSONDirectEncoder {
            return innerEncoder
        }
        
        @_lifetime(self: copy self)
        public mutating func encodeKey(keyEncoder: (inout JSONDirectEncoder.DictionaryKeyEncoder) throws(CodingError.Encoding) -> Void, valueEncoder: (inout JSONDirectEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
            innerEncoder.state.writer.prepareForObjectKey(first: !encodedFirstKey)
            try DictionaryKeyEncoder.withWrapper(&innerEncoder, closure: keyEncoder)
            
            encodedFirstKey = true
            
            innerEncoder.state.writer.prepareForObjectValue()
            try valueEncoder(&innerEncoder)
        }
        
        @inline(__always)
        @_alwaysEmitIntoClient
        @_lifetime(self: copy self)
        public mutating func encode(key: UTF8Span, valueEncoder: (inout JSONDirectEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
            try self.encode(key: key, checkForEscapes: true, valueEncoder: valueEncoder)
        }
        
        @_lifetime(self: copy self)
        public mutating func encode(key: UTF8Span, checkForEscapes: Bool, valueEncoder: (inout JSONDirectEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
            innerEncoder.state.writer.prepareForObjectKey(first: !encodedFirstKey)
            innerEncoder.state.writer.serializeStringSpan(key, checkForEscapes: checkForEscapes)
            encodedFirstKey = true
            
            innerEncoder.state.writer.prepareForObjectValue()
            
            innerEncoder.state.currentTopCodingPathNode.pointee.setDictionaryKey(key)
            try valueEncoder(&innerEncoder)
        }
        
        public var codingPath: CodingPath {
            innerEncoder.codingPath
        }
    }
   
    public struct DictionaryKeyEncoder: CommonEncoder, ~Copyable, ~Escapable {
        var innerEncoder: JSONDirectEncoder
        
        // TODO: Would prefer Never
        public typealias ArrayEncoder = JSONDirectEncoder.ArrayEncoder
        public typealias DictionaryEncoder = JSONDirectEncoder.DictionaryEncoder
        public typealias StructEncoder = JSONDirectEncoder.StructEncoder

        @_lifetime(self: copy self)
        public mutating func encodeString(_ string: String) throws(CodingError.Encoding) {
            try innerEncoder.encodeString(string)
            innerEncoder.state.currentTopCodingPathNode.pointee.setDictionaryKey(string.utf8Span)
        }
        
        @_lifetime(self: copy self)
        public mutating func encodeString(_ span: UTF8Span) throws(CodingError.Encoding) {
            try innerEncoder.encodeString(span)
            innerEncoder.state.currentTopCodingPathNode.pointee.setDictionaryKey(span)
        }
        
        // TODO: Integer implementations.
        
        public var codingPath: CodingPath {
            innerEncoder.codingPath
        }
        
        @_transparent
        @inline(__always)
        @_lifetime(encoder: copy encoder)
        static func withWrapper(_ encoder: inout JSONDirectEncoder, closure: (inout DictionaryKeyEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
            var wrapper = DictionaryKeyEncoder(innerEncoder: encoder)
            do {
                try closure(&wrapper)
                encoder = wrapper.innerEncoder
            } catch {
                encoder = wrapper.innerEncoder
                throw error
            }
        }
    }
   
    public typealias StructEncoder = DictionaryEncoder
}

// MARK: - Convenience Extensions for DictionaryEncoder

extension JSONDirectEncoder.DictionaryEncoder {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode(key: String, valueEncoder: (inout JSONDirectEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try self.encode(key: key.utf8Span, checkForEscapes: true, valueEncoder: valueEncoder)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode(field: some EncodingField, valueEncoder: (inout JSONDirectEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encode(key: span, checkForEscapes: true, valueEncoder: valueEncoder)
        }
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode(field: some JSONOptimizedEncodingField, valueEncoder: (inout JSONDirectEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encode(key: span, checkForEscapes: false, valueEncoder: valueEncoder)
        }
    }
    
    /// Convenience: encode a JSONEncodable value for a key.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & ~Copyable>(key: UTF8Span, checkForEscapes: Bool = true, value: borrowing T) throws(CodingError.Encoding) {
        try self.encode(key: key, checkForEscapes: checkForEscapes) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    /// Convenience: encode a JSONEncodable value for a key.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & ~Copyable>(key: String, value: borrowing T) throws(CodingError.Encoding) {
        try self.encode(key: key.utf8Span, checkForEscapes: true, value: value)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & ~Copyable>(field: some EncodingField, value: borrowing T) throws(CodingError.Encoding) {
        try self.encode(field: field) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & ~Copyable>(field: some JSONOptimizedEncodingField, value: borrowing T) throws(CodingError.Encoding) {
        try self.encode(field: field) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    /// Convenience: encode an Encodable value for a key.
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: Encodable>(key: UTF8Span, checkForEscapes: Bool = true, value: T) throws(CodingError.Encoding) {
        try self.encode(key: key, checkForEscapes: checkForEscapes) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    /// Convenience: encode an Encodable value for a key.
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: Encodable>(key: String, value: T) throws(CodingError.Encoding) {
        try self.encode(key: key.utf8Span, checkForEscapes: true, value: value)
    }
}

extension JSONDirectEncoder {
    public struct ArrayEncoder: CommonArrayEncoder, ~Copyable, ~Escapable {
        var innerEncoder: JSONDirectEncoder
        var encodedFirstValue: Bool
        
        @_lifetime(copy state)
        init(encodedFirstValue: Bool = false, state: consuming State) {
            self.innerEncoder = JSONDirectEncoder(state: state)
            self.encodedFirstValue = encodedFirstValue
        }
        
        @_lifetime(copy wrappingEncoder)
        init(encodedFirstValue: Bool = false, wrappingEncoder: consuming JSONDirectEncoder) {
            self.innerEncoder = wrappingEncoder
            self.encodedFirstValue = encodedFirstValue
        }
        
        @_lifetime(copy self)
        consuming func takeEncoder() -> JSONDirectEncoder {
            return innerEncoder
        }
        
        @_lifetime(self: copy self)
        public mutating func encodeElement(_ elementEncoder: (inout JSONDirectEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
            innerEncoder.state.writer.prepareForArrayElement(first: !encodedFirstValue)
            encodedFirstValue = true
            
            innerEncoder.state.currentTopCodingPathNode.pointee.incrementArrayIndex()
            try elementEncoder(&innerEncoder)
        }

        public var codingPath: CodingPath {
            innerEncoder.codingPath
        }
    }
}

// MARK: - Convenience Extensions for ArrayEncoder

extension JSONDirectEncoder.ArrayEncoder {
    /// Convenience: encode a JSONEncodable value.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & ~Copyable>(_ value: borrowing T) throws(CodingError.Encoding) {
        try self.encodeElement { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    /// Convenience: encode an Encodable value.
        @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: Encodable>(_ value: T) throws(CodingError.Encoding) {
        try self.encodeElement { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
}

extension JSONDirectEncoder {
    @_lifetime(self: copy self)
    public mutating func encodeStructFields(count: Int?, _ closure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try self.encodeDictionary(elementCount: count, closure)
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeDictionary(elementCount _: Int?, _ closure: (inout DictionaryEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try self.encodeDictionary(closure)
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeArray(elementCount _: Int?, _ closure: (inout ArrayEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try self.encodeArray(closure)
    }
    
    @_lifetime(self: copy self)
    public mutating func encodeBytes(_ bytes: some Sequence<UInt8>, count: Int?) throws(CodingError.Encoding) {
        // TODO: Use JSON Data encoding policy.
        try self.encodeArray { arrayEncoder throws(CodingError.Encoding) in
            for byte in bytes {
                try arrayEncoder.encode(byte)
            }
        }
    }
}

// MARK: - Convenience Extensions for Context-based Encoding

extension JSONDirectEncoder {
    /// Convenience: encode a JSONEncodable value using its default implementation.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & ~Copyable>(_ value: borrowing T) throws(CodingError.Encoding) {
        try value.encode(to: &self)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & CommonEncodable & ~Copyable>(_ value: borrowing T) throws(CodingError.Encoding) {
        @_transparent func asJSON<TAsJSON: JSONEncodable & ~Copyable>(_ jsonValue: borrowing TAsJSON) throws(CodingError.Encoding) {
            try self.encode(jsonValue)
        }
        return try asJSON(value)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodable & CommonEncodable>(_ value: borrowing T) throws(CodingError.Encoding) {
        @_transparent func asJSON<TAsJSON: JSONEncodable>(_ jsonValue: borrowing TAsJSON) throws(CodingError.Encoding) {
            try self.encode(jsonValue)
        }
        return try asJSON(value)
    }
    
    @_lifetime(self: copy self)
    public mutating func encode<T: CommonEncodable>(_ value: borrowing T) throws(CodingError.Encoding) {
        try self.encodeGeneric(value)
    }
    
    /// Convenience: encode using an explicit context (inout version for stateful contexts).
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodableWithContext & ~Copyable>(_ value: borrowing T, context: inout T.JSONEncodingContext) throws(CodingError.Encoding) {
        try value.encode(to: &self, context: &context)
    }
    
    /// Convenience: encode using an explicit context (copyable version for static member syntax).
    /// This enables clean syntax: `encoder.encode(date, context: .iso8601)`
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: JSONEncodableWithContext & ~Copyable>(_ value: borrowing T, context: T.JSONEncodingContext) throws(CodingError.Encoding) where T.JSONEncodingContext: Copyable {
        try value.encode(to: &self, context: context)
    }
}

// MARK: - Convenience Extension for Encodable support

extension JSONDirectEncoder {
    @_disfavoredOverload
    @_lifetime(self: copy self)
    public mutating func encode<T: Encodable>(_ value: T) throws(CodingError.Encoding) {
        do {
            let encoder = AdaptorEncoder<JSONPrimitive>(encoderContext: .init(userInfo: [:], options: state.options), codingPath: self.codingPath.toCodingKeys())
            try encoder.encode(value)
            let encodedValue = encoder.encodedValue
            try encodedValue.encode(to: &self)
        } catch {
            fatalError("TODO: Wrap/translate error")
        }
    }
}

extension NewJSONEncoder.Options.DateEncodingStrategy {
    func encode(date: Date, to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        switch self.storage {
        case .millisecondsSince1970:
            let value = 1000.0 * date.timeIntervalSince1970
            try encoder.encode(value)
        case .secondsSince1970:
            try encoder.encode(date.timeIntervalSince1970)
        case .iso8601:
            let string = date.formatted(.iso8601)
            try encoder.encode(string)
        case .formatted(let style):
            let string = date.formatted(style)
            try encoder.encode(string)
        case .deferredToDate:
            try encoder.encode(date.timeIntervalSinceReferenceDate)
        }
    }
}
