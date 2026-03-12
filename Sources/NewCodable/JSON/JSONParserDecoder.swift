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

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
import WASILibc
#endif

// TODO: EMBEDDED: Don't use the `final class` Internals type for Embedded only. We shouldn't have the same typed-throws overhead there anyway.

public struct JSONParserDecoder: JSONDecoderProtocol, ~Escapable {
    @usableFromInline
    internal typealias Options = NewJSONDecoder.Options
    
    // Structures with container nesting deeper than this limit are not valid.
    @usableFromInline
    internal static var maximumRecursionDepth: Int { 512 }
    
    @usableFromInline
    internal var state: ParserState
    
    @usableFromInline
    internal var midContainer: Bool
        
    @usableFromInline
    @_lifetime(copy state)
    init(state: ParserState, midContainer: Bool = false) {
        self.state = state
        self.midContainer = midContainer
    }
    
    public var codingPath: CodingPath {
        state.currentTopCodingPathNode.pointee.path
    }
    
    public typealias StructDecoder = DictionaryDecoder
    public struct DictionaryDecoder: JSONDictionaryDecoder, ~Escapable {
        public typealias FieldDecoder = JSONParserDecoder.FieldDecoder
        public typealias ValueDecoder = JSONParserDecoder
        
        @usableFromInline
        var parserState: ParserState
                
        @usableFromInline
        @_lifetime(copy parserState)
        init(parserState: ParserState, midContainer: Bool) throws(JSONError) {
            // Only check depth and increment when creating a new container
            if !midContainer {
                // Check depth limit before creating container
                guard parserState.depth < JSONParserDecoder.maximumRecursionDepth else {
                    throw JSONError.tooManyNestedArraysOrDictionaries()
                }
                
                self.parserState = parserState
                self.parserState.depth += 1
                
                let brace = try self.parserState.reader.consumeWhitespaceAndPeek()
                try self.parserState.reader.expectBeginningOfObject(brace)
                self.parserState.reader.moveReaderIndex(forwardBy: 1) // consume open brace
            } else {
                // For midContainer, just copy the state without depth changes
                self.parserState = parserState
            }
        }
        
        public var codingPath: CodingPath {
            parserState.currentTopCodingPathNode.pointee.path
        }
        
        @_lifetime(self: copy self)
        public mutating func decodeExpectedOrderField(required: Bool, matchingClosure: (UTF8Span) -> Bool, optimizedSafeStringKey: JSONSafeStringKey?, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
            do {
                // The dictionary could be empty.
                let nextChar = try parserState.reader.consumeWhitespaceAndPeek()
                if nextChar == ._closebrace {
                    return !required
                }
                
                try parserState.reader.expectBeginningOfObjectKey(nextChar)
                
                let savedPosition = parserState.reader.readOffset
                parserState.reader.moveReaderIndex(forwardBy: 1) // consume open quote
                let matches: Bool
                if let key = optimizedSafeStringKey {
                    matches = try parserState.reader.matchExpectedString(key.string)
                } else {
                    let parsed = try parserState.reader.parsedStringContentAndTrailingQuote()
                    switch parsed {
                    case .span(let span):
                        matches = matchingClosure(span)
                    case .string(let str, _):
                        matches = matchingClosure(str.utf8Span)
                    }
                }
                
                guard matches, parserState.reader.read() == ._quote else {
                    parserState.reader.readOffset = savedPosition
                    return !required
                }
                
                let sourceKeyBytes: UnsafeRawBufferPointer = parserState.reader.bytes.extracting(unchecked: savedPosition+1..<parserState.reader.readOffset-1).withUnsafeBytes{ $0 }
                
                let colon = try parserState.reader.consumeWhitespaceAndPeek()
                try parserState.reader.expectObjectKeyValueColon(colon)
                parserState.reader.moveReaderIndex(forwardBy: 1) // consume colon
                
                // Cheating a bit, using the StaticString parameter for the key here.
                parserState.currentTopCodingPathNode.pointee.setDictionaryKey(sourceKeyBytes)
                
                let preValueOffset = self.parserState.reader.readOffset
                var valueDecoder = JSONParserDecoder(state: self.parserState)
                valueDecoder.state.copyRelevantState(from: self.parserState)
                try valueDecoderClosure(&valueDecoder)
                if valueDecoder.state.reader.readOffset == preValueOffset {
                    try valueDecoder.state.skipValue()
                }
                self.parserState.copyRelevantState(from: valueDecoder.state)
                
                // TODO: What about EOF for assumed dictionary contents.
                let next = try parserState.reader.consumeWhitespaceAndPeek()
                switch next {
                case ._comma:
                    parserState.reader.moveReaderIndex(forwardBy: 1) // consume comma (which *could* be a trailing comma)
                    try parserState.reader.consumeWhitespaceAndPeek()
                case ._closebrace:
                    break // Wait for something else to consume brace
                default:
                    throw JSONError.unexpectedCharacter(context: "in object", ascii: next, location: parserState.reader.sourceLocation)
                }
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
            
            return true
        }
        
        @_lifetime(self: copy self)
        public mutating func decodeEachField(_ fieldDecoderClosure: (inout FieldDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
            
            do {
                // The dictionary could be empty.
                let nextChar = try parserState.reader.consumeWhitespaceAndPeek()
                if nextChar == ._closebrace {
                    return
                }
                
                // A single decoder value that will be reused for each individual sub-value.
                var valueDecoder = JSONParserDecoder(state: self.parserState)
                var foundQuote = nextChar == ._quote
                var foundCloseBrace = false
                while !foundCloseBrace {
                    guard foundQuote else {
                        throw JSONError.unexpectedCharacter(context: "at beginning of object key", ascii: parserState.reader.peek()!, location: parserState.reader.sourceLocation)
                    }
                    parserState.reader.moveReaderIndex(forwardBy: 1) // consume open quote
                    
                    let key = try parserState.reader.parsedStringContentAndTrailingQuote()
                    var fieldDecoder = FieldDecoder(string: key)
                    try fieldDecoderClosure(&fieldDecoder)
                    
                    let colon = try parserState.reader.consumeWhitespaceAndPeek()
                    try parserState.reader.expectObjectKeyValueColon(colon)
                    parserState.reader.moveReaderIndex(forwardBy: 1) // consume colon
                    
                    parserState.currentTopCodingPathNode.pointee.setDictionaryKey(key.buffer)
                    
                    let preValueOffset = self.parserState.reader.readOffset
                    valueDecoder.state.copyRelevantState(from: self.parserState)
                    try valueDecoderClosure(&valueDecoder)
                    if valueDecoder.state.reader.readOffset == preValueOffset {
                        try valueDecoder.state.skipValue()
                    }
                    self.parserState.copyRelevantState(from: valueDecoder.state)
                    
                    // TODO: What about EOF for assumed dictionary contents.
                    let next = try parserState.reader.consumeWhitespaceAndPeek()
                    switch next {
                    case ._comma:
                        parserState.reader.moveReaderIndex(forwardBy: 1) // consume comma (which *could* be a trailing comma)
                        
                        switch try parserState.reader.consumeWhitespaceAndPeek() {
                        case ._quote: foundQuote = true
                        case ._closebrace: foundCloseBrace = true
                        default: break
                        }
                    case ._closebrace:
                        foundCloseBrace = true
                    default:
                        throw JSONError.unexpectedCharacter(context: "in object", ascii: next, location: parserState.reader.sourceLocation)
                    }
                }
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
        }
        
        // TODO: Take care of all this code duplication here and above--without sacrificing performance.
        @_lifetime(self: copy self)
        public mutating func decodeEachKeyAndValue(_ closure: (String, inout ValueDecoder) throws(CodingError.Decoding) -> Bool) throws(CodingError.Decoding) {
            do {
                // The dictionary could be empty.
                let nextChar = try parserState.reader.consumeWhitespaceAndPeek()
                if nextChar == ._closebrace {
                    // TODO: Can we support multiple flattens? When if the first invocation got everything and stopped on the close brace, the second one saw the close brace and consumed it, and then the third one sees data outside the object?
                    return
                }
                
                // A single decoder value that will be reused for each individual sub-value.
                var valueDecoder = JSONParserDecoder(state: self.parserState)
                var foundQuote = nextChar == ._quote
                var foundCloseBrace = false
                while !foundCloseBrace {
                    guard foundQuote else {
                        throw JSONError.unexpectedCharacter(context: "at beginning of object key", ascii: parserState.reader.peek()!, location: parserState.reader.sourceLocation)
                    }
                    parserState.reader.moveReaderIndex(forwardBy: 1) // consume open quote
                    
                    var key = ""
                    let keySpan = try parserState.reader.parseStringContentAndTrailingQuote(&key)
                    
                    let colon = try parserState.reader.consumeWhitespaceAndPeek()
                    try parserState.reader.expectObjectKeyValueColon(colon)
                    parserState.reader.moveReaderIndex(forwardBy: 1) // consume colon
                    
                    // Update coding path with the key
                    keySpan.withUnsafeBytes {
                        parserState.currentTopCodingPathNode.pointee.setDictionaryKey($0)
                    }
                    
                    let preValueOffset = self.parserState.reader.readOffset
                    valueDecoder.state.copyRelevantState(from: self.parserState)
                    let stopped = try closure(key, &valueDecoder)
                    if valueDecoder.state.reader.readOffset == preValueOffset {
                        try valueDecoder.state.skipValue()
                    }
                    self.parserState.copyRelevantState(from: valueDecoder.state)
                    
                    // TODO: What about EOF for assumed dictionary contents.
                    let next = try parserState.reader.consumeWhitespaceAndPeek()
                    switch next {
                    case ._comma:
                        parserState.reader.moveReaderIndex(forwardBy: 1) // consume comma (which *could* be a trailing comma)
                        
                        switch try parserState.reader.consumeWhitespaceAndPeek() {
                        case ._quote: foundQuote = true
                        case ._closebrace: foundCloseBrace = true
                        default: break
                        }
                    case ._closebrace:
                        foundCloseBrace = true
                    default:
                        throw JSONError.unexpectedCharacter(context: "in object", ascii: next, location: parserState.reader.sourceLocation)
                    }
                    
                    // If stopped, exit loop by returning early, before potentially consuming a close brace. Parser should be queued up to the next quote or the close brace.
                    if stopped { return }
                }
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
        }
        
        @_lifetime(self: copy self)
        public mutating func decodeKeyAndValue(_ closure: (String, inout JSONParserDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
            var key: String = ""
            return try self.decodeKey { keyDecoder throws(CodingError.Decoding) in
                key = try keyDecoder.decode(String.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                try closure(key, &valueDecoder)
            }
        }
        
        @_lifetime(self: copy self)
        public mutating func withWrappingDecoder<T>(_ closure: (inout ValueDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
            var decoder = JSONParserDecoder(state: self.parserState, midContainer: true)
            let result = try closure(&decoder)
            self.parserState.copyRelevantState(from: decoder.state)
            return result
        }
        
        public func prepareIntermediateValueStorage() -> JSONIntermediateKeyValueStorage {
            .init(options: self.parserState.options[])
        }
        
        @usableFromInline
        @_lifetime(self: copy self)
        internal mutating func _finish() throws(CodingError.Decoding) {
            // In many cases we may have already fouund the close brace. If we haven't, then we have to decode and skip value any remaining values.
            if parserState.reader.peek() != ._closebrace {
                try self.decodeEachField { _ in /* do nothing */ } andValue: { _ in /* do nothing */ }
                assert(parserState.reader.peek() == ._closebrace)
            }
            parserState.reader.moveReaderIndex(forwardBy: 1) // consume close brace
            parserState.depth -= 1
        }
    }
    
    public struct FieldDecoder: JSONFieldDecoder, ~Escapable {
        @usableFromInline
        let string: ParserState.DocumentReader.ParsedString
        
        @_lifetime(copy string)
        init(string: ParserState.DocumentReader.ParsedString) {
            self.string = string
        }
        
        @_alwaysEmitIntoClient
        @inlinable
        public func decode<T: DecodingField>(_: T.Type) throws(CodingError.Decoding) -> T {
            switch string {
            case .span(let span):
                return try T.field(for: span)
            case .string(let string, _):
                return try T.field(for: string)
            }
        }
        
        @_alwaysEmitIntoClient
        public func matches(_ field: some DecodingField) -> Bool {
            switch string {
            case .span(let span):
                field.matches(span)
            case .string(let string, _):
                field.matches(string)
            }
        }
        
        // TODO: Only testing this because the above don't appear to inline like I want.
        @_alwaysEmitIntoClient
        public func matches(_ key: StaticString) -> Bool {
            switch string {
            case .span(let span):
                return span.span.withUnsafeBufferPointer { buff in
                    guard key.utf8CodeUnitCount == buff.count else {
                        return false
                    }
                    return memcmp(key.utf8Start, buff.baseAddress!, key.utf8CodeUnitCount) == 0
                }
            case .string(let string, _):
                return key.description == string
            }
        }
    }
    
    public struct ArrayDecoder: JSONArrayDecoder, ~Escapable {
        public typealias ElementDecoder = JSONParserDecoder
        
        var innerParser: JSONParserDecoder
        var hasNext: Bool
        
        @_lifetime(copy parserState)
        init(parserState: ParserState, midContainer: Bool) throws(JSONError) {
            self.innerParser = .init(state: parserState)
            
            if !midContainer {
                // Check depth limit before creating container
                guard parserState.depth < JSONParserDecoder.maximumRecursionDepth else {
                    throw JSONError.tooManyNestedArraysOrDictionaries()
                }
                
                self.innerParser.state.depth += 1
                try innerParser.parseArrayBeginning()
            }
            hasNext = try innerParser.prepareForArrayElement(first: true, consumingCloseBracket: false)
        }
        
        public var codingPath: CodingPath {
            innerParser.codingPath
        }
        
        @_lifetime(self: copy self)
        public mutating func decodeNext<T: ~Copyable>(_ closure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T? {
            do {
                guard hasNext else {
                    return nil
                }
                let result = try closure(&innerParser)
                hasNext = try innerParser.prepareForArrayElement(first: false, consumingCloseBracket: false)
                self.innerParser.state.currentTopCodingPathNode.pointee.incrementArrayIndex()
                return result
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
        }
        
        @_lifetime(self: copy self)
        public mutating func decodeEachElement(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
            do {
                repeat {
                    self.innerParser.state.currentTopCodingPathNode.pointee.incrementArrayIndex()
                    try closure(&innerParser)
                } while try self.innerParser.prepareForArrayElement(first: false, consumingCloseBracket: false)
                hasNext = false
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
        }
        
        @_lifetime(self: copy self)
        internal mutating func _finish() throws(CodingError.Decoding) {
            while let _ = try decodeNext(BlackHoleDecodable.self) { }
            self.innerParser.finishArray()
        }
    }
    


    @_lifetime(self: copy self)
    public mutating func decodeStruct<T: ~Copyable>(_ closure: (inout StructDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var dictionaryNode: InlineArray = [
            CodingPathNode.newDictionaryNode(withParent: state.currentTopCodingPathNode)
        ]
        var nodeSpan = dictionaryNode.mutableSpan
        state.currentTopCodingPathNode = nodeSpan.withUnsafeMutableBufferPointer {
            $0.baseAddress!
        }
        defer {
            withExtendedLifetime(nodeSpan) {
                state.currentTopCodingPathNode.unwindToParent()
            }
        }
        
        do {
            var decoder = try StructDecoder(parserState: self.state, midContainer: self.midContainer)
            let result = try closure(&decoder)
            if !midContainer {
                try decoder._finish()
            }
            self.state.copyRelevantState(from: decoder.parserState)
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeDictionary<T: ~Copyable>(_ closure: (inout DictionaryDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        try self.decodeStruct(closure)
    }
    
    
    @_lifetime(self: copy self)
    public mutating func decodeArray<T: ~Copyable>(_ closure: (inout ArrayDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var arrayNode: InlineArray = [
            CodingPathNode.newArrayNode(withParent: state.currentTopCodingPathNode)
        ]
        var nodeSpan = arrayNode.mutableSpan
        state.currentTopCodingPathNode = nodeSpan.withUnsafeMutableBufferPointer {
            $0.baseAddress!
        }
        defer {
            withExtendedLifetime(nodeSpan) {
                state.currentTopCodingPathNode.unwindToParent()
            }
        }
        
        do {
            var decoder = try ArrayDecoder(parserState: self.state, midContainer: self.midContainer)
            let result = try closure(&decoder)
            // TODO: Test if not all elements parsed.
            try decoder._finish()
            self.state.copyRelevantState(from: decoder.innerParser.state)
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    // MARK: - Enum Decoding
    
    /// Decodes an enum case with no associated values from `{"caseName":{}}` format
    @_lifetime(self: copy self)
    public mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (inout FieldDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T {
        // Check depth limit before creating container
        guard state.depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries(location: state.reader.sourceLocation).at(self.codingPath)
        }
        
        // Set up coding path node for the enum wrapper dictionary
        var dictionaryNode: InlineArray = [
            CodingPathNode.newDictionaryNode(withParent: state.currentTopCodingPathNode)
        ]
        var nodeSpan = dictionaryNode.mutableSpan
        state.currentTopCodingPathNode = nodeSpan.withUnsafeMutableBufferPointer {
            $0.baseAddress!
        }
        defer {
            withExtendedLifetime(nodeSpan) {
                state.currentTopCodingPathNode.unwindToParent()
            }
        }
        
        state.depth += 1
        defer { state.depth -= 1 }
        
        do {
            // Parse opening brace
            let openBrace = try state.reader.consumeWhitespaceAndPeek()
            guard openBrace == ._openbrace else {
                throw JSONError.unexpectedCharacter(context: "expecting enum object", ascii: openBrace, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            // Parse the case name (key)
            let openQuote = try state.reader.consumeWhitespaceAndPeek()
            guard openQuote == ._quote else {
                throw JSONError.unexpectedCharacter(context: "expecting enum case name", ascii: openQuote, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            let caseName = try state.reader.parsedStringContentAndTrailingQuote()
            
            // Update coding path
            state.currentTopCodingPathNode.pointee.setDictionaryKey(caseName.buffer)
            
            var fieldDecoder = FieldDecoder(string: caseName)
            let result = try closure(&fieldDecoder)
            
            // Parse colon
            let colon = try state.reader.consumeWhitespaceAndPeek()
            guard colon == ._colon else {
                throw JSONError.unexpectedCharacter(context: "after enum case name", ascii: colon, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            // Verify empty object value: {}
            let valueOpenBrace = try state.reader.consumeWhitespaceAndPeek()
            guard valueOpenBrace == ._openbrace else {
                throw JSONError.unexpectedCharacter(context: "expecting empty object for value-less enum", ascii: valueOpenBrace, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            let closeBrace = try state.reader.consumeWhitespaceAndPeek()
            guard closeBrace == ._closebrace else {
                throw JSONError.unexpectedCharacter(context: "expecting empty object for value-less enum", ascii: closeBrace, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            // Parse closing brace of outer object
            let outerCloseBrace = try state.reader.consumeWhitespaceAndPeek()
            guard outerCloseBrace == ._closebrace else {
                throw JSONError.unexpectedCharacter(context: "after enum value", ascii: outerCloseBrace, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    /// Decodes an enum case with associated values from `{"caseName":{"field1":value1,...}}` format
    @_lifetime(self: copy self)
    public mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (_ caseName: inout FieldDecoder, _ associatedValues: inout StructDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T {
        // Check depth limit before creating container
        guard state.depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries(location: state.reader.sourceLocation).at(self.codingPath)
        }
        
        // Set up coding path node for the enum wrapper dictionary
        var outerDictionaryNode: InlineArray = [
            CodingPathNode.newDictionaryNode(withParent: state.currentTopCodingPathNode)
        ]
        var outerNodeSpan = outerDictionaryNode.mutableSpan
        state.currentTopCodingPathNode = outerNodeSpan.withUnsafeMutableBufferPointer {
            $0.baseAddress!
        }
        defer {
            withExtendedLifetime(outerNodeSpan) {
                state.currentTopCodingPathNode.unwindToParent()
            }
        }
        
        state.depth += 1
        defer { state.depth -= 1 }
        
        do {
            // Parse opening brace
            let openBrace = try state.reader.consumeWhitespaceAndPeek()
            guard openBrace == ._openbrace else {
                throw JSONError.unexpectedCharacter(context: "expecting enum object", ascii: openBrace, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            // Parse the case name (key)
            let openQuote = try state.reader.consumeWhitespaceAndPeek()
            guard openQuote == ._quote else {
                throw JSONError.unexpectedCharacter(context: "expecting enum case name", ascii: openQuote, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            let caseName = try state.reader.parsedStringContentAndTrailingQuote()
            
            // Update coding path with case name
            state.currentTopCodingPathNode.pointee.setDictionaryKey(caseName.buffer)
            
            var fieldDecoder = FieldDecoder(string: caseName)
            
            // Parse colon
            let colon = try state.reader.consumeWhitespaceAndPeek()
            guard colon == ._colon else {
                throw JSONError.unexpectedCharacter(context: "after enum case name", ascii: colon, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            // Parse associated values dictionary - use midContainer: false so it handles the braces
            let preValueOffset = state.reader.readOffset
            var valueDecoder = try StructDecoder(parserState: state, midContainer: false)
            let result = try closure(&fieldDecoder, &valueDecoder)
            
            // Skip if not consumed, and finish the struct (consume closing brace)
            if valueDecoder.parserState.reader.readOffset == preValueOffset {
                try valueDecoder.parserState.skipValue()
            } else {
                try valueDecoder._finish()
            }
            
            state.copyRelevantState(from: valueDecoder.parserState)
            
            // Parse closing brace of outer object
            let next = try state.reader.consumeWhitespaceAndPeek()
            let foundCloseBrace: Bool
            switch next {
            case ._comma:
                state.reader.moveReaderIndex(forwardBy: 1)
                foundCloseBrace = try state.reader.consumeWhitespaceAndPeek() == ._closebrace
            case ._closebrace:
                foundCloseBrace = true
            default:
                foundCloseBrace = false
            }
            
            guard foundCloseBrace else {
                throw JSONError.unexpectedCharacter(context: "after enum object", ascii: next, location: state.reader.sourceLocation)
            }
            state.reader.moveReaderIndex(forwardBy: 1)
            
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @usableFromInline
    @_lifetime(self: copy self)
    internal mutating func parseDictionaryBeginning() throws(JSONError) {
        let byte = try state.reader.consumeWhitespaceAndPeek()
        try state.reader.expectBeginningOfObject(byte)
        state.reader.moveReaderIndex(forwardBy: 1) // Consume open brace.
    }
    
    @usableFromInline
    @_lifetime(self: copy self)
    internal mutating func prepareForDictKey(first: Bool) throws(JSONError) -> Bool {
        let byte = try state.reader.consumeWhitespaceAndPeek()
        switch (first, byte) {
        case (_, ._closebrace):
            state.reader.moveReaderIndex(forwardBy: 1) // Consume close brace.
            return false
        case (false, ._comma):
            state.reader.moveReaderIndex(forwardBy: 1) // Consume comma.
            let nextChar = try state.reader.consumeWhitespaceAndPeek()
            if try state.reader.expectBeginningOfObjectKey(nextChar, orEndOfObjectAfterTrailingQuote: true) == false {
                state.reader.moveReaderIndex(forwardBy: 1) // Consume close brace.
                return false
            }
            fallthrough // to quote
        case (true, ._quote):
            state.reader.moveReaderIndex(forwardBy: 1) // Consume quote.
            return true
        default:
            throw .unexpectedCharacter(context: "in object", ascii: byte, location: state.reader.sourceLocation)
        }
    }
    
    @usableFromInline
    @_lifetime(self: copy self)
    internal mutating func prepareForDictValue() throws(JSONError) {
        let colon = try state.reader.consumeWhitespaceAndPeek()
        try state.reader.expectObjectKeyValueColon(colon)
        state.reader.moveReaderIndex(forwardBy: 1) // consume colon
    }
    
    // TODO: See below on [Element] decoder for relevant comments.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func decode<Key: CodingStringKeyRepresentable, Value: JSONDecodable>(_: [Key:Value].Type, sizeHint: Int = 0) throws(CodingError.Decoding) -> [Key:Value] {
        do {
            try parseDictionaryBeginning()
            
            guard try prepareForDictKey(first: true) else {
                return [:]
            }
            
            var result = [Key:Value]()
            if sizeHint > 0 {
                result.reserveCapacity(sizeHint)
            }
            
            // TODO: Append to codingpath.
            
            repeat {
                let parsed = try state.reader.parsedStringContentAndTrailingQuote()
                let key = switch parsed {
                case .span(let span):
                    try Key.codingStringKeyVisitor.visitUTF8Bytes(span)
                case .string(let string, _):
                    try Key.codingStringKeyVisitor.visitString(string)
                }
                try prepareForDictValue()
                let value = try self.decode(Value.self)
                result[key] = value
            } while try prepareForDictKey(first: false)
            
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw (error as! CodingError.Decoding).addingIfNecessary(codingPath: self.codingPath)
        }
    }
    
    @usableFromInline
    @_lifetime(self: copy self)
    internal mutating func parseArrayBeginning() throws(JSONError) {
        let byte = try state.reader.consumeWhitespaceAndPeek()
        try state.reader.expectBeginningOfArray(byte)
        state.reader.moveReaderIndex(forwardBy: 1) // Consume open bracket.
    }
    
    @usableFromInline
    @_lifetime(self: copy self)
    internal mutating func prepareForArrayElement(first: Bool, consumingCloseBracket: Bool = true) throws(JSONError) -> Bool {
        let byte = try state.reader.consumeWhitespaceAndPeek()
        switch (first, byte) {
        case (_, ._closebracket):
            if consumingCloseBracket {
                state.reader.moveReaderIndex(forwardBy: 1) // Consume close bracket
            }
            return false
        case (false, ._comma):
            state.reader.moveReaderIndex(forwardBy: 1) // Consume comma
            if try state.reader.consumeWhitespaceAndPeek() == ._closebracket {
                if consumingCloseBracket {
                    state.reader.moveReaderIndex(forwardBy: 1) // Consume close bracket
                }
                return false
            }
            return true
        case (true, _):
            return true
        default:
            throw .unexpectedCharacter(context: "in array", ascii: byte, location: state.reader.sourceLocation)
        }
    }
    
    @_lifetime(self: copy self)
    internal mutating func finishArray() {
        assert(state.reader.peek() == ._closebracket)
        state.reader.moveReaderIndex(forwardBy: 1) // Consume close bracket
        state.depth -= 1
    }
    
    @inlinable
    @_lifetime(self: copy self)
    public mutating func decode<Element: JSONDecodable>(_: [Element].Type, sizeHint: Int = 0) throws(CodingError.Decoding) -> [Element] {
        do {
            try parseArrayBeginning()
            
            guard try prepareForArrayElement(first: true) else {
                return []
            }
            
            var result = [Element]()
            if sizeHint > 0 {
                result.reserveCapacity(sizeHint)
            }
            
            var arrayNode: InlineArray = [
                CodingPathNode.array(-1, parent: state.currentTopCodingPathNode)
            ]
            var nodeSpan = arrayNode.mutableSpan
            state.currentTopCodingPathNode = nodeSpan.withUnsafeMutableBufferPointer {
                $0.baseAddress!
            }
            defer {
                withExtendedLifetime(nodeSpan) {
                    state.currentTopCodingPathNode.unwindToParent()
                }
            }
            
            repeat {
                state.currentTopCodingPathNode.pointee.incrementArrayIndex()
                
                let value = try self.decode(Element.self)
                result.append(value)
            } while try prepareForArrayElement(first: false)
            
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @inlinable
    @_lifetime(self: copy self)
    public mutating func decode<Element: JSONDecodableWithContext>(_: [Element].Type, context: inout Element.JSONDecodingContext, sizeHint: Int = 0) throws(CodingError.Decoding) -> [Element] {
        do {
            try parseArrayBeginning()
            
            guard try prepareForArrayElement(first: true) else {
                return []
            }
            
            var result = [Element]()
            if sizeHint > 0 {
                result.reserveCapacity(sizeHint)
            }
            
            var arrayNode: InlineArray = [
                CodingPathNode.array(-1, parent: state.currentTopCodingPathNode)
            ]
            var nodeSpan = arrayNode.mutableSpan
            state.currentTopCodingPathNode = nodeSpan.withUnsafeMutableBufferPointer {
                $0.baseAddress!
            }
            defer {
                withExtendedLifetime(nodeSpan) {
                    state.currentTopCodingPathNode.unwindToParent()
                }
            }
            
            repeat {
                state.currentTopCodingPathNode.pointee.incrementArrayIndex()
                
                let value = try Element.decode(from: &self, context: &context)
                result.append(value)
            } while try prepareForArrayElement(first: false)
            
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func _finishDecode() throws(CodingError.Decoding) {
        do throws(JSONError) {
            if let nonWhitespace = try state.reader.consumeWhitespaceAndPeek(allowingEOF: true) {
                throw JSONError.unexpectedCharacter(context: "after top-level values", ascii: nonWhitespace, location: state.reader.sourceLocation)
            }
        } catch {
            throw error.at(.init([]))
        }
    }
}

extension JSONParserDecoder {
    
    @_lifetime(self: copy self)
    public mutating func decode(_: Bool.Type) throws(CodingError.Decoding) -> Bool {
        do {
            let byte = try state.reader.consumeWhitespaceAndPeek()
            switch byte {
            case UInt8(ascii: "f"), UInt8(ascii: "t"):
                return try state.reader.readBool()
            default:
                throw state.reader.decodingError(expectedTypeDescription: "boolean", at: codingPath)
            }
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Int.Type) throws(CodingError.Decoding) -> Int {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Int8.Type) throws(CodingError.Decoding) -> Int8 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Int16.Type) throws(CodingError.Decoding) -> Int16 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Int32.Type) throws(CodingError.Decoding) -> Int32 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Int64.Type) throws(CodingError.Decoding) -> Int64 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: UInt.Type) throws(CodingError.Decoding) -> UInt {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: UInt8.Type) throws(CodingError.Decoding) -> UInt8 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: UInt16.Type) throws(CodingError.Decoding) -> UInt16 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: UInt32.Type) throws(CodingError.Decoding) -> UInt32 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: UInt64.Type) throws(CodingError.Decoding) -> UInt64 {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Float.Type) throws(CodingError.Decoding) -> Float {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Double.Type) throws(CodingError.Decoding) -> Double {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            return try state.decode(hint)
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_: String.Type) throws(CodingError.Decoding) -> String {
        do {
            let byte = try state.reader.consumeWhitespaceAndPeek()
            switch byte {
            case ._quote:
                state.reader.moveReaderIndex(forwardBy: 1) // consume start quote.
                var key = ""
                _ = try state.reader.parseStringContentAndTrailingQuote(&key)
                return key
            default:
                throw state.reader.decodingError(expectedTypeDescription: "string", at: codingPath)
            }
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @inlinable
    @_lifetime(self: copy self)
    public mutating func decodeString<V: DecodingStringVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V) throws(CodingError.Decoding) -> V.DecodedValue {
        do {
            let byte = try state.reader.consumeWhitespaceAndPeek()
            switch byte {
            case ._quote:
                state.reader.moveReaderIndex(forwardBy: 1) // consume start quote.
                let parsed = try state.reader.parsedStringContentAndTrailingQuote()
                switch parsed {
                case .span(let span):
                    return try visitor.visitUTF8Bytes(span)
                case .string(let string, _):
                    return try visitor.visitString(string)
                }
            default:
                throw state.reader.decodingError(expectedTypeDescription: "string", at: codingPath)
            }
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw (error as! CodingError.Decoding).addingIfNecessary(codingPath: self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeNumber() throws(CodingError.Decoding) -> JSONPrimitive.Number {
        do {
            try state.reader.consumeWhitespaceAndPeek()
            let start = state.reader.readOffset
            let (_, _) = state.reader.skipNumber()
            let end = state.reader.readOffset
            guard end > start else {
                throw state.reader.decodingError(expectedTypeDescription: "number", at: codingPath)
            }
            let span = state.reader.bytes.extracting(unchecked: start..<end)
            let utf8Span = UTF8Span(unchecked: .init(_bytes: span), isKnownASCII: true)
            return .init(extendedPrecisionRepresentation: String(copying: utf8Span))
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw (error as! CodingError.Decoding).addingIfNecessary(codingPath: self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeNil() throws(CodingError.Decoding) -> Bool {
        do {
            let byte = try state.reader.consumeWhitespaceAndPeek()
            switch byte {
            case UInt8(ascii: "n"):
                return try state.reader.matchExpectedString("null")
            default:
                return false
            }
        } catch {
            throw error.at(self.codingPath)
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeOptional(_ closure: (inout Self) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
        if try self.decodeNil() {
            return
        }
        try closure(&self)
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Date.Type) throws(CodingError.Decoding) -> Date {
        return try self.state.options[].dateDecodingStrategy.decodeDate(from: &self)
    }
    
    @_lifetime(self: copy self)
    public mutating func decode(_ hint: Data.Type) throws(CodingError.Decoding) -> Data {
        return try self.state.options[].dataDecodingStrategy.decodeData(from: &self)
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeAny<V: JSONDecodingVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V) throws(CodingError.Decoding) -> V.DecodedValue {
        // TODO: Add coding path
        do {
            let byte = try state.reader.consumeWhitespaceAndPeek()
            let result: V.DecodedValue
            switch byte {
            case ._quote:
                result = try self.decodeString(visitor)
            case ._openbrace:
                result = try self.decodeDictionary { dictDecoder throws(CodingError.Decoding) in
                    try visitor.visit(decoder: &dictDecoder)
                }
            case ._openbracket:
                result = try self.decodeArray { seqDecoder throws(CodingError.Decoding) in
                    try visitor.visit(decoder: &seqDecoder)
                }
            case UInt8(ascii: "f"), UInt8(ascii: "t"):
                let bool = try state.reader.readBool()
                result = try visitor.visit(bool)
            case UInt8(ascii: "n"):
                try state.reader.readNull()
                result = try visitor.visitNone()
            case UInt8(ascii: "-"):
                result = try state.decodeUnhintedNumber(visitor, isNegative: true)
            case _asciiNumbers:
                result = try state.decodeUnhintedNumber(visitor, isNegative: false)
            case ._space, ._return, ._newline, ._tab:
                fatalError("Expected that all white space is consumed")
            default:
                throw JSONError.unexpectedCharacter(ascii: byte, location: state.reader.sourceLocation)
            }
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeJSONPrimitive() throws(CodingError.Decoding) -> JSONPrimitive {
        return try decodeAny(JSONElementVisitor())
    }
    
    @_disfavoredOverload
    @_lifetime(self: copy self)
    public mutating func decode<T: Decodable>(_ t: T.Type) throws(CodingError.Decoding) -> T {
        // First decode into a JSONPrimitive
        let jsonValue = try self.decodeJSONPrimitive()
        
        // Create an AdaptorDecoder with the JSONPrimitive
        let decoder = AdaptorDecoder(
            value: jsonValue,
            decoderContext: JSONPrimitive.DecoderContext(
                userInfo: [:], // JSONParserDecoder doesn't currently track userInfo
                options: self.state.options[]
            ),
            codingPath: self.codingPath.toCodingKeys()
        )
        
        do {
            return try T(from: decoder)
        } catch {
            fatalError("TODO: Convert/wrap error")
        }
    }
}

extension JSONParserDecoder {
    private struct JSONElementVisitor: JSONDecodingVisitor {
        typealias DecodedValue = JSONPrimitive

        func visit(decoder: inout some JSONArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> JSONPrimitive {
            var array = [JSONPrimitive]()
            try decoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                let element = try elementDecoder.decodeJSONPrimitive()
                array.append(element)
            }
            return .array(array)
        }
        
        func visit(decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> JSONPrimitive {
            var elements = [(key: String, value: JSONPrimitive)]()
            try decoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                elements.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
            }
            return .dictionary(elements)
        }
        
        var prefersArbitraryPrecisionNumbers: Bool { true }
        
        func visitArbitraryPrecisionNumber(_ span: UTF8Span) throws(CodingError.Decoding) -> JSONPrimitive {
            .number(.init(extendedPrecisionRepresentation: String(copying: span)))
        }
        
        func visitArbitraryPrecisionNumber(_ string: String) throws(CodingError.Decoding) -> JSONPrimitive {
            .number(.init(extendedPrecisionRepresentation: string))
        }
        
        func visitNone() throws(CodingError.Decoding) -> JSONPrimitive {
            .null
        }
        
        func visit(_ bool: Bool) throws(CodingError.Decoding) -> JSONPrimitive {
            .bool(bool)
        }
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
            return .string(String(copying: buffer))
        }
        
        func visitString(_ string: String) throws(CodingError.Decoding) -> DecodedValue {
            .string(string)
        }
    }
}

// Data / Date visitors

extension JSONParserDecoder {
    internal struct Base64Visitor: DecodingStringVisitor {
        public typealias DecodedValue = Data
        public func visitString(_ string: String) throws(CodingError.Decoding) -> Data {
            guard let result = Data(base64Encoded: string) else {
                throw CodingError.dataCorrupted(debugDescription: "Invalid base64 encoded string")
            }
            return result
        }
        public func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> Data {
            // TODO: No-copy
            guard let result = Data(base64Encoded: Data(_copying: buffer.span.bytes)) else {
                throw CodingError.dataCorrupted(debugDescription: "Invalid base64 encoded string")
            }
            return result
        }
        public init() { }
    }
    
    internal enum DateNumberVisitor: DecodingNumberVisitor {
        typealias DecodedValue = Date
        
        case referenceDate
        case secondsSince1970
        case msSince1970
        
        func visit(_ integer: Int64) throws(CodingError.Decoding) -> Date {
            switch self {
            case .referenceDate:
                Date(timeIntervalSinceReferenceDate: TimeInterval(integer))
            case .secondsSince1970:
                Date(timeIntervalSince1970: TimeInterval(integer))
            case .msSince1970:
                Date(timeIntervalSince1970: TimeInterval(integer) / 1000.0)
            }
        }
        func visit(_ integer: UInt64) throws(CodingError.Decoding) -> Date {
            switch self {
            case .referenceDate:
                Date(timeIntervalSinceReferenceDate: TimeInterval(integer))
            case .secondsSince1970:
                Date(timeIntervalSince1970: TimeInterval(integer))
            case .msSince1970:
                Date(timeIntervalSince1970: TimeInterval(integer) / 1000.0)
            }
        }
        func visit(_ double: Double) throws(CodingError.Decoding) -> Date {
            switch self {
            case .referenceDate:
                Date(timeIntervalSinceReferenceDate: TimeInterval(double))
            case .secondsSince1970:
                Date(timeIntervalSince1970: TimeInterval(double))
            case .msSince1970:
                Date(timeIntervalSince1970: TimeInterval(double) / 1000.0)
            }
        }
    }
    
    internal enum DateStringVistior: DecodingStringVisitor {
        typealias DecodedValue = Date
        
        case iso8601
        case formatted(any ParseStrategy)
        
        // TODO: I'd probably prefer the default to be the other way in this case. Or maybe they both need defaults?
        
        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> Date {
            // TODO: Inefficient.
            return try visitString(String(copying: buffer))
        }
        
        // TODO: opening the existential here unhappily, since ParseStrategy doesn't have primary associated types.
        func useParseStrategy<S: ParseStrategy>(_ strategy: S, on input: String) throws(CodingError.Decoding) -> Date {
            do {
                return try strategy.parse(input as! S.ParseInput) as! Date
            } catch {
                fatalError("TODO: Convert/wrap error")
            }
        }
        
        func visitString(_ string: String) throws(CodingError.Decoding) -> Date {
            switch self {
            case .iso8601:
                guard let date = try? Date.ISO8601FormatStyle().parse(string) else {
                    throw CodingError.dataCorrupted(debugDescription: "IS08601 date parsing failed")
                }
                return date
            case .formatted(let parseStrategy):
                return try self.useParseStrategy(parseStrategy, on: string)
            }
        }
    }
}

// CodingPathNode

extension UnsafeMutablePointer<JSONParserDecoder.CodingPathNode> {
    @usableFromInline
    mutating func unwindToParent() {
        switch self.pointee {
        case .root: fatalError("Can't unwind coding path past root")
        case .array(_, parent: let ptr): self = ptr
        case .dictionary(_, parent: let ptr): self = ptr
        }
    }
}

extension JSONParserDecoder {
    // Note: This is a distinct type from JSONParserEncoder.CodingPathNode, because we track dictionary strings as, eventually, RawSpans instead of Strings (ideally) or UTF8Spans. The interpretation of the bytes is also different.
    @usableFromInline
    enum CodingPathNode {
        case root
        case array(Int, parent: UnsafeMutablePointer<CodingPathNode>)
        // TODO: If/when we can make CodingPathNode: ~Escapable, I believe we can have `.dictionary` contain a `String` instead of a UTF8Span, which will avoid the cost of BOTH retain/release AND `.utf8Span`.
        case dictionary(UnsafeRawBufferPointer, parent: UnsafeMutablePointer<CodingPathNode>)
        // We could consider a "simpleDictionaryKey" case that tracks our knowledge of whether the string had escapes or not. However optimizing the CPU time of constructing the coding path is not paramount right now.
        
        @usableFromInline
        @inline(__always)
        static func newDictionaryNode(withParent parent: UnsafeMutablePointer<CodingPathNode>) -> Self {
            .dictionary(UnsafeRawBufferPointer(_empty: ()), parent: parent)
        }
        
        @usableFromInline
        @inline(__always)
        static func newArrayNode(withParent parent: UnsafeMutablePointer<CodingPathNode>) -> Self {
            .array(-1, parent: parent)
        }
        
        @inline(__always)
        mutating func setDictionaryKey(_ key: UnsafeRawBufferPointer) {
            guard case .dictionary(_, let parent) = self else {
                preconditionFailure("Wrong node type")
            }
            self = .dictionary(key, parent: parent)
        }
        
        @usableFromInline
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
                    components.append(.stringKey(String._tryFromUTF8(buffer.assumingMemoryBound(to: UInt8.self))!))
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
}

// CommonCodable

extension JSONParserDecoder: CommonDecoder {
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func decodeGenericCommon<T: CommonDecodable>(_ type: T.Type) throws(CodingError.Decoding) -> T {
        // Cover all the types that JSONDecoder supports specially that CommonDecodable does not.
        if type == Date.self {
            return _identityCast(try self.decode(Date.self), to: T.self)
        }
        if type == Data.self {
            return _identityCast(try self.decode(Data.self), to: T.self)
        }
        if type == URL.self {
            fatalError("TBD")
            // TODO: Should this also be a primitive of JSON protocols?
//            return try self.decode(URL.self) as! T
        }
        if type == Decimal.self {
            fatalError("TBD")
            // TODO: Should this also be a primitive of JSON protocols?
//            return try self.decode(Decimal.self) as! T
        }
        return try T.decode(from: &self)
    }
    
    /// Convenience: decode a JSONDecodable & CommonDecodable type using the JSONDecodable implementation.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func decode<T: JSONDecodable & CommonDecodable & ~Copyable>(_ type: T.Type) throws(CodingError.Decoding) -> T {
        @_transparent func asJSON<TAsJSON: JSONDecodable & ~Copyable>(_ type: TAsJSON.Type) throws(CodingError.Decoding) -> TAsJSON {
            try decode(TAsJSON.self)
        }
        return try asJSON(type)
    }
    
    @_lifetime(self: copy self)
    public mutating func decode<T: CommonDecodable>(_ t: T.Type) throws(CodingError.Decoding) -> T where T: Copyable {
        try decodeGenericCommon(t)
    }
    
    @inlinable
    @_lifetime(self: copy self)
    public mutating func decode<Key: CodingStringKeyRepresentable, Value: CommonDecodable>(_: [Key:Value].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Key:Value] {
        do {
            try parseDictionaryBeginning()
            
            guard try prepareForDictKey(first: true) else {
                return [:]
            }
            
            var result = [Key:Value]()
            if sizeHint > 0 {
                result.reserveCapacity(sizeHint)
            }
            
            // TODO: Append to codingpath.
            
            repeat {
                let parsed = try state.reader.parsedStringContentAndTrailingQuote()
                let key = switch parsed {
                case .span(let span):
                    try Key.codingStringKeyVisitor.visitUTF8Bytes(span)
                case .string(let string, _):
                    try Key.codingStringKeyVisitor.visitString(string)
                }
                try prepareForDictValue()
                let value = try self.decode(Value.self)
                result[key] = value
            } while try prepareForDictKey(first: false)
            
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw (error as! CodingError.Decoding).addingIfNecessary(codingPath: self.codingPath)
        }
    }
    
    @inlinable
    @_lifetime(self: copy self)
    public mutating func decode<Element: CommonDecodable>(_: [Element].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Element] {
        do {
            try parseArrayBeginning()
            
            guard try prepareForArrayElement(first: true) else {
                return []
            }
            
            var result = [Element]()
            if sizeHint > 0 {
                result.reserveCapacity(sizeHint)
            }
            
            // TODO: Append to CodingPath
            
            repeat {
                let value = try self.decode(Element.self)
                result.append(value)
            } while try prepareForArrayElement(first: false)
            
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }

    internal
    struct JSONBytesArrayIterator: DecodingBytesIterator, ~Copyable, ~Escapable {
        var state: ParserState
        var first = true
        var foundCloseBracket = false

        @_lifetime(copy incomingState)
        init(state incomingState: ParserState) {
            state = incomingState
        }
        
        @_lifetime(self: copy self)
        mutating func finish() throws(JSONError) {
            do {
                // TODO: Meh? This check presumes that the client has already processed all the bytes. What is the right thing to do if they don't.
                while !foundCloseBracket {
                    _ = try self.next()
                }
                state.reader.moveReaderIndex(forwardBy: 1) // Consume close bracket.
            } catch {
                fatalError("TODO: Error types are confusing here")
            }
        }
        
        @_lifetime(self: copy self)
        mutating func next() throws(CodingError.Decoding) -> UInt8? {
            do {
                guard !foundCloseBracket else { return nil }
                
                switch try state.reader.consumeWhitespaceAndPeek() {
                case ._closebracket:
                    foundCloseBracket = true
                    return nil
                case ._comma where first == false:
                    state.reader.moveReaderIndex(forwardBy: 1) // Consume comma.
                    if try state.reader.consumeWhitespaceAndPeek() == ._closebracket {
                        foundCloseBracket = true
                        return nil
                    }
                default:
                    break
                }
                defer {
                    first = false
                }
                
                return try state.decode(UInt8.self)
            } catch {
                throw error.at(state.codingPath)
            }
        }
    }
    
    struct JSONParserStringByteIterator: JSONByteIterator, ~Copyable, ~Escapable {
        var state: ParserState
        var foundCloseQuote = false
        
        @_lifetime(copy state)
        init(state: ParserState) {
            self.state = state
        }
        
        mutating func nextByte() throws(JSONError) -> UInt8? {
            if foundCloseQuote { return nil }
            
            guard let nextChar = state.reader.read() else {
                throw .unexpectedEndOfFile
            }
            guard nextChar != ._quote else {
                foundCloseQuote = true
                return nil
            }
            
            return nextChar
        }
        
        mutating func finish() throws(JSONError) {
            if !foundCloseQuote {
                while state.reader.peek() != ._quote {
                    state.reader.moveReaderIndex(forwardBy: 1)
                }
                state.reader.moveReaderIndex(forwardBy: 1) // Skip end quote.
            }
        }
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeBytes<V: DecodingBytesVisitor>(visitor: V) throws(CodingError.Decoding) -> V.DecodedValue {
        // TODO: Add codingPath to visitor errors.
        do {
            // TODO: Respect data decoding options?
            let byte = try state.reader.consumeWhitespaceAndPeek()
            switch byte {
            case ._quote:
                state.reader.moveReaderIndex(forwardBy: 1) // consume quote
                var b64Iterator = JSONBase64ByteIterator(iterator: JSONParserStringByteIterator(state: self.state))
                let result = try visitor.visitBytes(&b64Iterator)
                try b64Iterator.finish()
                self.state.copyRelevantState(from: b64Iterator.iterator.state)
                return result
            case ._openbracket:
                state.reader.moveReaderIndex(forwardBy: 1) // consume open bracket
                var iterator = JSONBytesArrayIterator(state: state)
                let result = try visitor.visitBytes(&iterator)
                try iterator.finish()
                self.state.copyRelevantState(from: iterator.state)
                return result
            default:
                throw state.reader.decodingError(expectedTypeDescription: "base64 string or integer array", at: self.codingPath)
            }
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    public var supportsDecodeAny: Bool {
        true
    }
    
    @_lifetime(self: copy self)
    public mutating func decodeAny<V: CommonDecodingVisitor>(_ visitor: V) throws(CodingError.Decoding) -> V.DecodedValue {
        do {
            let byte = try state.reader.consumeWhitespaceAndPeek()
            let result: V.DecodedValue
            switch byte {
            case ._quote:
                result = try self.decodeString(visitor)
            case ._openbrace:
                // TODO: Dict + array. Test when not all elements are parsed.
                var dictDecoder = try DictionaryDecoder(parserState: self.state, midContainer: false)
                result = try visitor.visit(decoder: &dictDecoder)
                try dictDecoder._finish()
                self.state.copyRelevantState(from: dictDecoder.parserState)
            case ._openbracket:
                var seqDecoder = try ArrayDecoder(parserState: self.state, midContainer: false)
                result = try visitor.visit(decoder: &seqDecoder)
                try seqDecoder._finish()
                self.state.copyRelevantState(from: seqDecoder.innerParser.state)
            case UInt8(ascii: "f"), UInt8(ascii: "t"):
                let bool = try state.reader.readBool()
                result = try visitor.visit(bool)
            case UInt8(ascii: "n"):
                try state.reader.readNull()
                result = try visitor.visitNone()
            case UInt8(ascii: "-"):
                result = try state.decodeUnhintedNumberCommon(visitor, isNegative: true)
            case _asciiNumbers:
                result = try state.decodeUnhintedNumberCommon(visitor, isNegative: false)
            case ._space, ._return, ._newline, ._tab:
                fatalError("Expected that all white space is consumed")
            default:
                throw JSONError.unexpectedCharacter(ascii: byte, location: state.reader.sourceLocation)
            }
            return result
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }
    
    public mutating func decodePrimitive() throws(CodingError.Decoding) -> JSONPrimitive {
        try self.decodeJSONPrimitive()
    }
}

extension JSONParserDecoder.FieldDecoder: CommonFieldDecoder {
    
}

extension JSONParserDecoder.ArrayDecoder: CommonArrayDecoder {
    public var sizeHint: Int? { nil }
}

extension JSONParserDecoder.StructDecoder: CommonStructDecoder {
    @_lifetime(self: copy self)
    public mutating func decodeExpectedOrderField(required: Bool, matchingClosure: (UTF8Span) -> Bool, andValue valueDecoderClosure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
        try self.decodeExpectedOrderField(required: required, matchingClosure: matchingClosure, optimizedSafeStringKey: nil, andValue: valueDecoderClosure)
    }
    
    public var sizeHint: Int? { nil }
}

extension JSONParserDecoder.DictionaryDecoder: CommonDictionaryDecoder {
    // TODO: No wrong. Needs to limit to strings!
    public typealias KeyDecoder = JSONParserDecoder
    
    @_lifetime(self: copy self)
    public mutating func decodeEachKey(_ keyDecodingClosure: (inout KeyDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecodingClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
        
        do {
            
            // The dictionary could be empty.
            let nextChar = try parserState.reader.consumeWhitespaceAndPeek()
            if nextChar == ._closebrace {
                return
            }
            
            // A single decoder value that will be reused for each individual sub-key and sub-value.
            var decoder = JSONParserDecoder(state: self.parserState)
            var foundCloseBrace = false
            while !foundCloseBrace {
                let preKeyOffset = self.parserState.reader.readOffset
                decoder.state.copyRelevantState(from: self.parserState)
                try keyDecodingClosure(&decoder)
                if decoder.state.reader.readOffset == preKeyOffset {
                    try decoder.state.skipValue()
                }
                self.parserState.copyRelevantState(from: decoder.state)
                
                let colon = try parserState.reader.consumeWhitespaceAndPeek()
                guard colon == ._colon else {
                    throw JSONError.unexpectedCharacter(context: "in object", ascii: colon, location: parserState.reader.sourceLocation)
                }
                parserState.reader.moveReaderIndex(forwardBy: 1) // consume colon
                
                let preValueOffset = self.parserState.reader.readOffset
                decoder.state.copyRelevantState(from: self.parserState)
                try valueDecodingClosure(&decoder)
                if decoder.state.reader.readOffset == preValueOffset {
                    try decoder.state.skipValue()
                }
                self.parserState.copyRelevantState(from: decoder.state)
                
                // TODO: What about EOF for assumed dictionary contents.
                let next = try parserState.reader.consumeWhitespaceAndPeek()
                switch next {
                case ._comma:
                    parserState.reader.moveReaderIndex(forwardBy: 1) // consume comma (which *could* be a trailing comma)
                    let nextChar = try parserState.reader.consumeWhitespaceAndPeek()
                    if try parserState.reader.expectBeginningOfObjectKey(nextChar, orEndOfObjectAfterTrailingQuote: true) == false {
                        foundCloseBrace = true
                    }
                case ._closebrace:
                    foundCloseBrace = true
                default:
                    throw JSONError.unexpectedCharacter(context: "in object", ascii: next, location: parserState.reader.sourceLocation)
                }
            }
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }

    }
    
    @_lifetime(self: copy self)
    public mutating func decodeKey(_ keyDecodingClosure: (inout KeyDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecodingClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
        
        do {
            // The dictionary could be empty.
            let nextChar = try parserState.reader.consumeWhitespaceAndPeek()
            if nextChar == ._closebrace {
                return false
            }
            
            // A single decoder value that will be reused for each individual sub-key and sub-value.
            var decoder = JSONParserDecoder(state: self.parserState)
            
            let preKeyOffset = self.parserState.reader.readOffset
            decoder.state.copyRelevantState(from: self.parserState)
            try keyDecodingClosure(&decoder)
            if decoder.state.reader.readOffset == preKeyOffset {
                try decoder.state.skipValue()
            }
            self.parserState.copyRelevantState(from: decoder.state)
            
            let colon = try parserState.reader.consumeWhitespaceAndPeek()
            guard colon == ._colon else {
                throw JSONError.unexpectedCharacter(context: "in object", ascii: colon, location: parserState.reader.sourceLocation)
            }
            parserState.reader.moveReaderIndex(forwardBy: 1) // consume colon
            
            let preValueOffset = self.parserState.reader.readOffset
            decoder.state.copyRelevantState(from: self.parserState)
            try valueDecodingClosure(&decoder)
            if decoder.state.reader.readOffset == preValueOffset {
                try decoder.state.skipValue()
            }
            self.parserState.copyRelevantState(from: decoder.state)
            
            // TODO: What about EOF for assumed dictionary contents.
            let next = try parserState.reader.consumeWhitespaceAndPeek()
            switch next {
            case ._comma:
                parserState.reader.moveReaderIndex(forwardBy: 1) // consume comma (which *could* be a trailing comma)
            case ._closebrace:
                break
            default:
                throw JSONError.unexpectedCharacter(context: "in object", ascii: next, location: parserState.reader.sourceLocation)
            }
            
            return true
        } catch let error as JSONError {
            throw error.at(self.codingPath)
        } catch {
            // TODO: Fix unsavory language workaround
            throw error as! CodingError.Decoding
        }
    }

}


