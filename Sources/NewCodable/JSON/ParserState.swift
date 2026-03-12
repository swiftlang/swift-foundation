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

#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(BasicContainers)
internal import BasicContainers
#endif

extension JSONParserDecoder {
    
    @usableFromInline
    internal struct ParserState: ~Escapable {
        @usableFromInline
        var reader: DocumentReader

        @usableFromInline
        var depth: Int = 0
        
        @usableFromInline
        let options: _Borrow<NewJSONDecoder.Options>
        
        @usableFromInline
        var currentTopCodingPathNode: UnsafeMutablePointer<CodingPathNode>
        
        @inlinable
        @_lifetime(copy span, copy options)
        init(span: RawSpan, options: _Borrow<NewJSONDecoder.Options>, topCodingPathNode: UnsafeMutablePointer<CodingPathNode>) {
            self.reader = .init(bytes: span)
            self.options = options
            self.currentTopCodingPathNode = topCodingPathNode
        }
        
        @usableFromInline
        var codingPath: CodingPath {
            self.currentTopCodingPathNode.pointee.path
        }

        @usableFromInline
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func copyRelevantState(from state: ParserState) {
            self.reader.readOffset = state.reader.readOffset
            self.currentTopCodingPathNode = state.currentTopCodingPathNode
            self.depth = state.depth
        }
        
        @inlinable
        @_lifetime(self: copy self)
        mutating func skipString() throws(JSONError) {
            reader.moveReaderIndex(forwardBy: 1) // consume start quote.
            try reader.skipUTF8StringTillNextUnescapedQuote()
            reader.moveReaderIndex(forwardBy: 1) // consume end quote.
        }
        
        @_lifetime(self: copy self) mutating func decode(_ t: Int.Type) throws(CodingError.Decoding) -> Int { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: Int8.Type) throws(CodingError.Decoding) -> Int8 { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: Int16.Type) throws(CodingError.Decoding) -> Int16 { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: Int32.Type) throws(CodingError.Decoding) -> Int32 { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: Int64.Type) throws(CodingError.Decoding) -> Int64 { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: UInt.Type) throws(CodingError.Decoding) -> UInt { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: UInt8.Type) throws(CodingError.Decoding) -> UInt8 { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: UInt16.Type) throws(CodingError.Decoding) -> UInt16 { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: UInt32.Type) throws(CodingError.Decoding) -> UInt32 { try decode() }
        @_lifetime(self: copy self) mutating func decode(_ t: UInt64.Type) throws(CodingError.Decoding) -> UInt64 { try decode() }
        
        @usableFromInline
        internal struct FloatingPointNonConformingStringValueVisitor<T: BinaryFloatingPoint & PrevalidatedJSONNumberBufferConvertible>: DecodingStringVisitor {
            @usableFromInline
            typealias DecodedValue = T
            
            @usableFromInline
            let policy: Options.NonConformingFloatDecodingStrategy
            @usableFromInline
            init(policy: Options.NonConformingFloatDecodingStrategy) {
                self.policy = policy
            }
            
            @usableFromInline
            func visitString(_ string: String) throws(CodingError.Decoding) -> T {
                switch policy {
                case .throw:
                    throw CodingError.typeMismatch(expectedType: T.self, actualValue: string)
                case .convertFromString(let positiveInfinity, let negativeInfinity, let nan):
                    switch string {
                    case positiveInfinity: return T.infinity
                    case negativeInfinity: return -T.infinity
                    case nan: return T.nan
                    default: throw CodingError.typeMismatch(expectedType: T.self, actualValue: string)
                    }
                }
            }
            
            @usableFromInline
            func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> T {
                // TODO: Inefficient.
                try self.visitString(String(copying: buffer))
            }
        }
        
        @inline(__always)
        @_lifetime(self: copy self)
        mutating func decodeFloatingPoint<T: BinaryFloatingPoint & PrevalidatedJSONNumberBufferConvertible>(_ t: T.Type) throws(CodingError.Decoding) -> T {
            do {
                guard let char = reader.peek() else {
                    throw JSONError.unexpectedEndOfFile
                }
                
                switch char {
                case ._quote:
                    let policy = self.options[].nonConformingFloatDecodingStrategy
                    var decoder = JSONParserDecoder(state: self)
                    let result = try decoder.decodeString(FloatingPointNonConformingStringValueVisitor<T>(policy: policy))
                    self.copyRelevantState(from: decoder.state)
                    return result
                case ._minus, _asciiNumbers:
                    return try reader.parseFloatingPoint(as: t)
                default:
                    throw decodingError(expectedTypeDescription: "floating point number")
                }
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
            
        }
        
        @_lifetime(self: copy self) mutating func decode(_ t: Float.Type) throws(CodingError.Decoding) -> Float { try self.decodeFloatingPoint(Float.self) }
        @_lifetime(self: copy self) mutating func decode(_ t: Double.Type) throws(CodingError.Decoding) -> Double { try self.decodeFloatingPoint(Double.self) }

        @inlinable
        @inline(__always)
        mutating func decode<T: FixedWidthInteger>() throws(CodingError.Decoding) -> T {
            // TODO: TEST NEGATIVE FLOATS HERE. I think `parseInteger` consumes the `-` and doesn't restore it on returning .retryAsFloatingPoint
            do {
                switch try reader.parseInteger(as: T.self) {
                case .pureInteger(let integer):
                    return integer
                case .retryAsFloatingPoint:
                    // TODO: Slowpath? Lots of inlined code here.
                    let double = try reader.parseFloatingPoint(as: Double.self)
                    guard let integer = T(exactly: double) else {
                        // TODO: Include the parsed string? Explain we're trying to represent as an integer?
                        throw JSONError.numberIsNotRepresentableInSwift(parsed: String(double))
                    }
                    
                    // TODO: Classic JSONDecoder would retry Decimal -> integer parsing
                    return integer
                case .notANumber:
                    throw decodingError(expectedTypeDescription: "integer number")
                }
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
        }
        
        @_lifetime(self: copy self)
        mutating func decodeUnhintedNumber<V: JSONDecodingVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V, isNegative: Bool) throws(CodingError.Decoding) -> V.DecodedValue {
            // Check if the visitor wants arbitrary precision numbers
            if visitor.prefersArbitraryPrecisionNumbers {
                let start = reader.readOffset
                let (_, _) = reader.skipNumber()
                let end = reader.readOffset
                
                let numberSpan = reader.bytes.extracting(unchecked: start..<end)
                // We're asserting here that `skipNumber` stops before any invalid JSON number bytes, which guarantees that we have ASCII.
                // TODO: 0 length spans?
                let utf8Span = UTF8Span(unchecked: .init(_bytes: numberSpan), isKnownASCII: true)
                return try visitor.visitArbitraryPrecisionNumber(utf8Span)
            }
            
            return try decodeUnhintedNumberCommon(visitor, isNegative: isNegative)
        }
        
        @_lifetime(self: copy self)
        mutating func decodeUnhintedNumberCommon<V: DecodingNumberVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V, isNegative: Bool) throws(CodingError.Decoding) -> V.DecodedValue {
            do {
                // TODO: Consider constraining the visited integer type to the smallest that will fit it. Default visitor implementations would promote back to the largest implemented visitor.
                if isNegative {
                    reader.moveReaderIndex(forwardBy: 1) // consume '-'
                    if case let .pureInteger(integer) = try reader._parseIntegerDigits(isNegative: true) as DocumentReader.IntegerParseResult<Int64> {
                        return try visitor.visit(integer)
                    }
                    // retry as floating point, push back `-`
                    reader.moveReaderIndex(forwardBy: -1)
                } else {
                    if case let .pureInteger(integer) = try reader._parseIntegerDigits(isNegative: false) as DocumentReader.IntegerParseResult<UInt64> {
                        return try visitor.visit(integer)
                    }
                }
                let double = try reader.parseFloatingPoint(as: Double.self)
                return try visitor.visit(double)
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
        }
        
        mutating func skipValue() throws(CodingError.Decoding) {
            do {
                let byte = try reader.consumeWhitespaceAndPeek()
                switch byte {
                case ._quote:
                    try skipString()
                case ._openbrace:
                    // TODO: Restore depth checks
                    var decoder = try JSONParserDecoder.StructDecoder(parserState: self, midContainer: false)
                    _ = try BlackHoleVisitor().visit(decoder: &decoder)
                    try decoder._finish()
                    self = decoder.parserState
                case ._openbracket:
                    // TODO: Restore depth checks
                    var decoder = try JSONParserDecoder.ArrayDecoder(parserState: self, midContainer: false)
                    _ = try BlackHoleVisitor().visit(decoder: &decoder)
                    try decoder._finish()
                    self = decoder.innerParser.state
                case UInt8(ascii: "f"), UInt8(ascii: "t"):
                    _ = try reader.readBool()
                case UInt8(ascii: "n"):
                    try reader.readNull()
                case UInt8(ascii: "-"), _asciiNumbers:
                    reader.skipNumber()
                case ._space, ._return, ._newline, ._tab:
                    assertionFailure("Expected that all white space is consumed")
                default:
                    throw JSONError.unexpectedCharacter(ascii: byte, location: reader.sourceLocation)
                }
            } catch let error as JSONError {
                throw error.at(self.codingPath)
            } catch {
                // TODO: Fix unsavory language workaround
                throw error as! CodingError.Decoding
            }
        }

        @frozen
        public struct DocumentReader: ~Escapable {

            // TODO: UTF8Span?
            @usableFromInline
            let bytes: RawSpan

            @usableFromInline
            internal var readOffset : Int

            @inlinable
            var endOffset: Int {
                bytes.byteCount
            }

            @inlinable
            @inline(__always)
            func checkRemainingBytes(_ count: Int) -> Bool {
                (endOffset - readOffset) >= count
            }

            @inlinable
            @inline(__always)
            func requireRemainingBytes(_ count: Int) throws(JSONError) {
                guard checkRemainingBytes(count) else {
                    throw JSONError.unexpectedEndOfFile
                }
            }

            @usableFromInline
            var sourceLocation : JSONError.SourceLocation {
                self.sourceLocation(atOffset: 0)
            }

            @usableFromInline
            func sourceLocation(atOffset offset: Int) -> JSONError.SourceLocation {
                .countingLinesAndColumns(upTo: readOffset + offset, in: bytes)
            }

            @inlinable
            @inline(__always)
            var isEOF: Bool {
                readOffset == endOffset
            }

            @inlinable
            @_lifetime(copy bytes)
            init(bytes: RawSpan) {
                self.bytes = bytes
                self.readOffset = 0
            }

            @inlinable
            @inline(__always)
            mutating func read() -> UInt8? {
                guard !isEOF else {
                    return nil
                }

                defer { readOffset &+= 1 }

                return bytes._loadByteUnchecked(readOffset)
            }

            @inlinable
            @inline(__always)
            func peek(offset: Int = 0) -> UInt8? {
                assert(offset >= 0)
                assert(0 <= readOffset)
                let peekIndex = readOffset &+ offset
                guard peekIndex < endOffset else {
                    return nil
                }

                return bytes._loadByteUnchecked(peekIndex)
            }

            @inlinable
            @inline(__always)
            func peek<T: BitwiseCopyable>(as type: T.Type) -> T? {
                assert(0 <= readOffset)
                guard checkRemainingBytes(MemoryLayout<T>.size) else {
                    return nil
                }
                return bytes.unsafeLoadUnaligned(fromUncheckedByteOffset: readOffset, as: type)
            }

            @inlinable
            @inline(__always)
            @_lifetime(self: copy self)
            mutating func moveReaderIndex(forwardBy offset: Int) {
                readOffset &+= offset
            }

            @inlinable
            @inline(__always)
            func index(offsetBy offset: Int) -> Int {
                readOffset &+ offset
            }

            @inlinable
            @inline(__always)
            func distance(from start: Int, to end: Int) -> Int {
                end - start
            }

            @inlinable
            @inline(__always)
            @_lifetime(copy self)
            func remainingBytes() -> RawSpan {
                bytes.extracting(readOffset...)
            }

            @inlinable
            static var whitespaceBitmap: UInt64 { 1 << UInt8._space | 1 << UInt8._return | 1 << UInt8._newline | 1 << UInt8._tab }

            @_effects(readnone)
            @inlinable
            internal static func u32LeadingWhitespaceBytes(_ u32: UInt32) -> Int {
                let spaceBits = (UInt32(UInt8._space) * (0x01010101 as UInt32))
                let returnBits = (UInt32(UInt8._return) * (0x01010101 as UInt32))
                let newlineBits = (UInt32(UInt8._newline) * (0x01010101 as UInt32))
                let tabBits = (UInt32(UInt8._tab) * (0x01010101 as UInt32))

                let spaceScratch = (u32 ^ spaceBits) &- (0x01010101 as UInt32)
                let returnScratch = (u32 ^ returnBits) &- (0x01010101 as UInt32)
                let newlineScratch = (u32 ^ newlineBits) &- (0x01010101 as UInt32)
                let tabScratch = (u32 ^ tabBits) &- (0x01010101 as UInt32)

                var scratch = spaceScratch | returnScratch | newlineScratch | tabScratch
                scratch = scratch & 0x80808080
                scratch = (scratch >> 7) * 255
                scratch = ~scratch

                return scratch.trailingZeroBitCount >> 3 // /8
            }

            @_effects(readnone)
            @inlinable
            internal static func u64LeadingWhitespaceBytes(_ u64: UInt64) -> Int {
                let spaceBits = (UInt64(UInt8._space) * (0x0101010101010101 as UInt64))
                let returnBits = (UInt64(UInt8._return) * (0x0101010101010101 as UInt64))
                let newlineBits = (UInt64(UInt8._newline) * (0x0101010101010101 as UInt64))
                let tabBits = (UInt64(UInt8._tab) * (0x0101010101010101 as UInt64))

                let spaceScratch = (u64 ^ spaceBits) &- (0x0101010101010101 as UInt64)
                let returnScratch = (u64 ^ returnBits) &- (0x0101010101010101 as UInt64)
                let newlineScratch = (u64 ^ newlineBits) &- (0x0101010101010101 as UInt64)
                let tabScratch = (u64 ^ tabBits) &- (0x0101010101010101 as UInt64)

                var scratch = spaceScratch | returnScratch | newlineScratch | tabScratch
//                let bits: UInt64 =
//                (
//                    ( (u64 ^  |
//                    ( (u64 ^ (UInt64(UInt8._return) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64) |
//                    ( (u64 ^ (UInt64(UInt8._newline) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64) |
//                    ( (u64 ^ (UInt64(UInt8._tab) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64)
//                )
//                & 0x8080808080808080
    //            print("0x\(String(u64, radix: 16)) ", bits != 0 ? "does" : "does NOT", " contain quote, backslash, or invalid characters")
                scratch = scratch & 0x8080808080808080
                scratch = (scratch >> 7) * 255
                scratch = ~scratch

                return scratch.trailingZeroBitCount >> 3 // /8
            }

            @_effects(readnone)
            @inlinable
            internal static func u128LeadingWhitespaceBytes(_ u64: UInt128) -> Int {
                let spaceBits = (UInt128(UInt8._space) * (0x01010101010101010101010101010101 as UInt128))
                let returnBits = (UInt128(UInt8._return) * (0x01010101010101010101010101010101 as UInt128))
                let newlineBits = (UInt128(UInt8._newline) * (0x01010101010101010101010101010101 as UInt128))
                let tabBits = (UInt128(UInt8._tab) * (0x01010101010101010101010101010101 as UInt128))

                let spaceScratch = (u64 ^ spaceBits) &- (0x01010101010101010101010101010101 as UInt128)
                let returnScratch = (u64 ^ returnBits) &- (0x01010101010101010101010101010101 as UInt128)
                let newlineScratch = (u64 ^ newlineBits) &- (0x01010101010101010101010101010101 as UInt128)
                let tabScratch = (u64 ^ tabBits) &- (0x01010101010101010101010101010101 as UInt128)

                var scratch = spaceScratch | returnScratch | newlineScratch | tabScratch
                scratch = scratch & 0x80808080808080808080808080808080
                scratch = (scratch >> 7) * 255
                scratch = ~scratch

                return scratch.trailingZeroBitCount >> 3 // /8
            }

            @_effects(readnone)
            @inlinable
            internal static func makeU64WhitespaceBitmap(_ u64: UInt64) -> UInt64 {
//                let testValue = UInt64(UInt8._space) << 56 | UInt64(UInt8._return) << 48 | UInt64(UInt8._newline) << 40 | UInt64(UInt8._tab) << 32

                let spaceBits = (UInt64(UInt8._space) * (0x0101010101010101 as UInt64))
                let returnBits = (UInt64(UInt8._return) * (0x0101010101010101 as UInt64))
                let newlineBits = (UInt64(UInt8._newline) * (0x0101010101010101 as UInt64))
                let tabBits = (UInt64(UInt8._tab) * (0x0101010101010101 as UInt64))

                let spaceScratch = (u64 ^ spaceBits) &- (0x0101010101010101 as UInt64)
                let returnScratch = (u64 ^ returnBits) &- (0x0101010101010101 as UInt64)
                let newlineScratch = (u64 ^ newlineBits) &- (0x0101010101010101 as UInt64)
                let tabScratch = (u64 ^ tabBits) &- (0x0101010101010101 as UInt64)

                let scratch = spaceScratch | returnScratch | newlineScratch | tabScratch
//                let bits: UInt64 =
//                (
//                    ( (u64 ^  |
//                    ( (u64 ^ (UInt64(UInt8._return) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64) |
//                    ( (u64 ^ (UInt64(UInt8._newline) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64) |
//                    ( (u64 ^ (UInt64(UInt8._tab) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64)
//                )
//                & 0x8080808080808080
    //            print("0x\(String(u64, radix: 16)) ", bits != 0 ? "does" : "does NOT", " contain quote, backslash, or invalid characters")
//                scratch = scratch & 0x8080808080808080
//                scratch = (scratch >> 7) * 255
//                scratch = ~scratch

//                return scratch.trailingZeroBitCount >> 3 // /8

//                let test1 = (testValue ^ spaceBits) &- (0x0101010101010101 as UInt64)
//                let test2 = (testValue ^ returnBits) &- (0x0101010101010101 as UInt64)
//                let test3 = (testValue ^ newlineBits) &- (0x0101010101010101 as UInt64)
//                let test4 = (testValue ^ tabBits) &- (0x0101010101010101 as UInt64)
//
//                let scratchTest = test1 | test2 | test3 | test4

                return scratch
            }

            @usableFromInline
//            @inline(never)
//            @inlinable
            @inline(__always)
            @discardableResult
            mutating func consumeWhitespaceAndPeek() throws(JSONError) -> UInt8 {
//                // If the next character is not whitespace, then we're done.
//                if readIndex < endIndex {
//                    let ascii = bytes[unchecked: readIndex]
//                    if Self.whitespaceBitmap & (1 << ascii) == 0 {
//                        return ascii
//                    }
//                }
//                bytes.formIndex(after: &readIndex)

                // TODO: This works, but is too expensive.
//                while self.checkRemainingBytes(MemoryLayout<UInt64>.size) {
//                    if let whitespaceBitmapIndex {
//                        let originalDistance = whitespaceBitmapIndex.distance(to: readIndex)
//                        var distance = originalDistance
//                        var foundNonwhitespace = false
//                        while distance < MemoryLayout<UInt64>.size {
//                            if (self.whitespaceBitmap & ((0x80 as UInt64) << (distance*8))) != 0 {
//                                distance += 1
//                            } else {
//                                foundNonwhitespace = true
//                                break
//                            }
//                        }
//                        let whitespaceBytesSkipped = distance - originalDistance
//                        if whitespaceBytesSkipped > 0 {
//                            bytes.formIndex(&readIndex, offsetBy: whitespaceBytesSkipped)
//                        }
//                        if foundNonwhitespace {
//                            return bytes[unchecked: readIndex]
//                        } else {
//                            // We exceeded the bitmap.
//                            self.whitespaceBitmapIndex = nil
//                        }
//                    } else {
//                        self.whitespaceBitmap = Self.makeU64WhitespaceBitmap(bytes.loadUnaligned(from: readIndex, as: UInt64.self))
//                        self.whitespaceBitmapIndex = readIndex
//                    }
//                }

//                // Read 8 bytes worth all at once.
//                while self.checkRemainingBytes(MemoryLayout<UInt64>.size) {
//                    let u64 = bytes.loadUnaligned(from: readIndex, as: UInt64.self)
//                    let whitespaceToSkip = Self.u64LeadingWhitespaceBytes(u64)
//                    switch whitespaceToSkip {
//                    case 0:
//                        return bytes[unchecked: readIndex]
//                    case 1...7:
//                        bytes.formIndex(&readIndex, offsetBy: whitespaceToSkip)
//                        return bytes[unchecked: readIndex]
//                    default:
//                        bytes.formIndex(&readIndex, offsetBy: 8)
//                        continue
//                    }
//                }

//                // Read 16 bytes worth all at once.
//                while self.checkRemainingBytes(MemoryLayout<UInt128>.size) {
//                    let u128 = bytes.loadUnaligned(from: readIndex, as: UInt128.self)
//                    let whitespaceToSkip = Self.u128LeadingWhitespaceBytes(u128)
//                    switch whitespaceToSkip {
//                    case 0:
//                        return bytes[unchecked: readIndex]
//                    case 1...15:
//                        bytes.formIndex(&readIndex, offsetBy: whitespaceToSkip)
//                        return bytes[unchecked: readIndex]
//                    default:
//                        bytes.formIndex(&readIndex, offsetBy: 16)
//                        continue
//                    }
//                }

//                // Read 4 bytes worth all at once.
//                while self.checkRemainingBytes(MemoryLayout<UInt32>.size) {
//                    let u32 = bytes.loadUnaligned(from: readIndex, as: UInt32.self)
//                    let whitespaceToSkip = Self.u32LeadingWhitespaceBytes(u32)
//                    switch whitespaceToSkip {
//                    case 0:
//                        return bytes[unchecked: readIndex]
//                    case 1...3:
//                        bytes.formIndex(&readIndex, offsetBy: whitespaceToSkip)
//                        return bytes[unchecked: readIndex]
//                    default:
//                        bytes.formIndex(&readIndex, offsetBy: 4)
//                        continue
//                    }
//                }

                var localReadIndex = readOffset
                defer {
                    readOffset = localReadIndex
                }
                
                while localReadIndex < endOffset {
                    let ascii = bytes._loadByteUnchecked(localReadIndex)
                    switch ascii {
                    case UInt8(ascii: " "), UInt8(ascii: "\r"), UInt8(ascii: "\n"), UInt8(ascii: "\t"):
                        localReadIndex &+= 1
                    default:
                        return ascii
                    }
                }

                throw JSONError.unexpectedEndOfFile
            }

//            @usableFromInline
//            @inline(never)
            @inlinable
            @inline(__always)
            @discardableResult
            @_lifetime(self: copy self)
            mutating func consumeWhitespaceAndPeek(allowingEOF: Bool) throws(JSONError) -> UInt8? {
                while readOffset < endOffset {
                    let ascii = bytes._loadByteUnchecked(readOffset)
                    switch ascii {
                    case ._space, ._return, ._newline, ._tab:
                        readOffset &+= 1
                    default:
                        return ascii
                    }
                }
                guard allowingEOF else {
                    throw JSONError.unexpectedEndOfFile
                }
                return nil
            }

            @usableFromInline
            @inline(never)
            @_lifetime(self: copy self)
            mutating func errorForUnmatchedCharacter(in str: StaticString, typeDescriptor: String) -> JSONError {
                // Figure out the exact character that is wrong.
                let badOffset = str.withUTF8Buffer { strBuffer in
                    let remainingBytes = bytes.extracting(readOffset..<endOffset)
                    for i in 0..<min(strBuffer.count, remainingBytes.byteCount) {
                        let strByte = strBuffer[i]
                        let spanByte = remainingBytes._loadByteUnchecked(i)
                        if strByte != spanByte {
                            return i
                        }
                    }
                    return 0 // should be unreachable
                }
                self.moveReaderIndex(forwardBy: badOffset)
                return JSONError.unexpectedCharacter(context: "in expected \(typeDescriptor) value", ascii: self.peek()!, location: sourceLocation)
            }
            
            @inlinable
            @inline(__always)
            @_lifetime(self: copy self)
            mutating func matchExpectedString(_ str: StaticString) throws(JSONError) -> Bool {
                do {
                    let cmp = try bytes.extracting(unchecked: readOffset..<endOffset).withUnsafeBytes { buff in
                        if buff.count < str.utf8CodeUnitCount { throw JSONError.unexpectedEndOfFile }
                        return memcmp(buff.baseAddress!, str.utf8Start, str.utf8CodeUnitCount)
                    }
                    guard cmp == 0 else {
                        return false
                    }
                    
                    // If all looks good, advance past the string.
                    self.moveReaderIndex(forwardBy: str.utf8CodeUnitCount)
                    return true
                } catch {
                    // TODO: Remove unsavory workaroud
                    throw error as! JSONError
                }
            }

            @inlinable
            @inline(__always)
            @_lifetime(self: copy self)
            mutating func readExpectedString(_ str: StaticString, typeDescriptor: String) throws(JSONError) {
                do {
                    let cmp = try bytes.extracting(unchecked: readOffset..<endOffset).withUnsafeBytes { buff in
                        if buff.count < str.utf8CodeUnitCount { throw JSONError.unexpectedEndOfFile }
                        return memcmp(buff.baseAddress!, str.utf8Start, str.utf8CodeUnitCount)
                    }
                    guard cmp == 0 else {
                        throw errorForUnmatchedCharacter(in: str, typeDescriptor: typeDescriptor)
                    }
                    
                    // If all looks good, advance past the string.
                    self.moveReaderIndex(forwardBy: str.utf8CodeUnitCount)
                } catch {
                    // TODO: Remove unsavory workaroud
                    throw error as! JSONError
                }
            }

            @inlinable
            @inline(__always)
            mutating func readBool() throws(JSONError) -> Bool {
                switch self.read() {
                case UInt8(ascii: "t"):
                    try readExpectedString("rue", typeDescriptor: "boolean")
                    return true
                case UInt8(ascii: "f"):
                    try readExpectedString("alse", typeDescriptor: "boolean")
                    return false
                default:
                    preconditionFailure("Expected to have `t` or `f` as first character")
                }
            }

            @inlinable
            @inline(__always)
            mutating func readNull() throws(JSONError) {
                try readExpectedString("null", typeDescriptor: "null")
            }

            // MARK: - Private Methods -

            // MARK: String

            @inlinable
            @_lifetime(self: copy self)
            internal mutating func _parseHexIntegerDigits<Result: FixedWidthInteger>(totalDigits: Int, isNegative: Bool) throws(JSONError) -> Result {
                let startOffset = self.readOffset

                // ASCII constants, named for clarity:
                let _0 = 48 as UInt8, _A = 65 as UInt8, _a = 97 as UInt8

                let numericalUpperBound = _0 &+ 10
                let uppercaseUpperBound = _A &+ 6
                let lowercaseUpperBound = _a &+ 6
                let multiplicand: Result = 16

                var remainingDigits = totalDigits
                var result = 0 as Result
                while remainingDigits > 0, let digit = read() {
                    remainingDigits -= 1

                    let digitValue: Result
                    if _fastPath(digit >= _0 && digit < numericalUpperBound) {
                        digitValue = Result(truncatingIfNeeded: digit &- _0)
                    } else if _fastPath(digit >= _A && digit < uppercaseUpperBound) {
                        digitValue = Result(truncatingIfNeeded: digit &- _A &+ 10)
                    } else if _fastPath(digit >= _a && digit < lowercaseUpperBound) {
                        digitValue = Result(truncatingIfNeeded: digit &- _a &+ 10)
                    } else {
                        // TODO: Meh `!`
                        let hexString = String._tryFromUTF8(self.bytes.extracting(unchecked: startOffset ..< self.readOffset))
                        throw .invalidHexDigitSequence(hexString!, location: .countingLinesAndColumns(upTo: startOffset, in: self.bytes))
                    }

                    let overflow1: Bool
                    (result, overflow1) = result.multipliedReportingOverflow(by: multiplicand)
                    let overflow2: Bool
                    (result, overflow2) = isNegative
                    ? result.subtractingReportingOverflow(digitValue)
                    : result.addingReportingOverflow(digitValue)
                    guard _fastPath(!overflow1 && !overflow2) else {
                        // TODO: Meh `!`
                        let hexString = String._tryFromUTF8(self.bytes.extracting(unchecked: startOffset ..< self.readOffset))
                        throw .invalidHexDigitSequence(hexString!, location: .countingLinesAndColumns(upTo: startOffset, in: self.bytes))
                    }
                }
                if remainingDigits > 0 {
                    throw .unexpectedEndOfFile
                }
                return result
            }

            @inlinable
            @_lifetime(self: copy self)
            internal mutating func _parseUnicodeHexSequence(allowNulls: Bool = true) throws(JSONError) -> UInt16 {
                let startIndex = self.readOffset
                let result: UInt16 = try _parseHexIntegerDigits(totalDigits: 4, isNegative: false)
                guard allowNulls || result != 0 else {
                    throw .invalidEscapedNullValue(location: .countingLinesAndColumns(upTo: startIndex, in: bytes))
                }
                return result
            }

            // Shared with JSON5, which requires allowNulls = false for compatibility.
            @_lifetime(self: copy self)
            internal mutating func _parseUnicodeSequence(into string: inout UniqueArray<UInt8>, allowNulls: Bool = true) throws(JSONError) {
                // we build this for utf8 only for now.
                let startIndex = readOffset
                let bitPattern = try _parseUnicodeHexSequence(allowNulls: allowNulls)

                // check if lead surrogate
                if UTF16.isLeadSurrogate(bitPattern) {
                    // if we have a lead surrogate we expect a trailing surrogate next
                    let trailingSurrogateStartIndex = readOffset
                    let leadingSurrogateBitPattern = bitPattern
                    guard read() == ._backslash, read() == UInt8(ascii: "u") else {
                        throw .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .countingLinesAndColumns(upTo: trailingSurrogateStartIndex, in: bytes))
                    }

                    let trailingSurrogateBitPattern = try _parseUnicodeHexSequence(allowNulls: true)
                    guard UTF16.isTrailSurrogate(trailingSurrogateBitPattern) else {
                        throw .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .countingLinesAndColumns(upTo: trailingSurrogateStartIndex, in: bytes))
                    }

                    let encodedScalar = UTF16.EncodedScalar([leadingSurrogateBitPattern, trailingSurrogateBitPattern])
                    let unicode = UTF16.decode(encodedScalar)
                    UTF8.encode(unicode) { codeUnit in
                        string.append(codeUnit)
                    }
                } else {
                    guard let unicode = Unicode.Scalar(bitPattern) else {
                        throw .couldNotCreateUnicodeScalarFromUInt32(location: .countingLinesAndColumns(upTo: startIndex, in: bytes), unicodeScalarValue: UInt32(bitPattern))
                    }
                    UTF8.encode(unicode) { codeUnit in
                        string.append(codeUnit)
                    }
                }
            }

            @_lifetime(self: copy self)
            internal mutating func _parseEscapeSequence(into string: inout UniqueArray<UInt8>) throws(JSONError) {
                while let next = read() {
                    switch next {
                    case UInt8(ascii:"\""):
                        return string.append(.init(ascii: "\""))
                    case UInt8(ascii:"\\"):
                        return string.append(.init(ascii: "\\"))
                    case UInt8(ascii:"/"):
                        return string.append(.init(ascii: "/"))
                    case UInt8(ascii:"b"):
                        return string.append(0x08) // \b
                    case UInt8(ascii:"f"):
                        return string.append(0x0C) // \f
                    case UInt8(ascii:"n"):
                        return string.append(0x0A) // \n
                    case UInt8(ascii:"r"):
                        return string.append(0x0D) // \r
                    case UInt8(ascii:"t"):
                        return string.append(0x09) // \t
                    case UInt8(ascii:"u"):
                        return try _parseUnicodeSequence(into: &string)
                    default:
                        // TODO: This doesn't work any more, since the offsets don't translate.
                        throw .unexpectedEscapedCharacter(ascii: next, location: .countingLinesAndColumns(upTo: readOffset, in: bytes))
                    }
                }
                throw .unexpectedEndOfFile
            }

            @_lifetime(self: copy self)
            internal mutating func _slowpath_continueParsingString(into output: inout UniqueArray<UInt8>) throws(JSONError) {
                // Continue scanning, taking into account escaped sequences and control characters
                let startOffset = self.readOffset
                var chunkStart = startOffset

                while true {
                    let byte = try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter()
                    switch byte {
                    case ._backslash, ._quote:
                        if readOffset > chunkStart {
                            let span = bytes.extracting(unchecked: chunkStart..<readOffset)
                            span.withUnsafeBytes {
                                output.append(copying: $0)
                            }
                        }
                        moveReaderIndex(forwardBy: 1)

                        if byte == ._backslash {
                            try _parseEscapeSequence(into: &output)
                            chunkStart = self.readOffset
                        } else if byte == ._quote {
                            return
                        }

                    default:
                        // All Unicode characters may be placed within the quotation marks, except for the characters that must be escaped: quotation mark, reverse solidus, and the control characters (U+0000 through U+001F).
                        // TODO: This doesn't work any more, since the offsets don't translate.
                        throw JSONError.unescapedControlCharacterInString(ascii: byte, location: .countingLinesAndColumns(upTo: readOffset, in: bytes))
                    }
                }

                throw JSONError.unexpectedEndOfFile
            }

            @frozen
            @usableFromInline
            enum ParsedString: ~Escapable {
                case string(String, UTF8Span)
                case span(UTF8Span)
                
                var buffer: UnsafeRawBufferPointer {
                    switch self {
                    case .string(_, let span), .span(let span):
                        span.span.bytes.withUnsafeBytes {
                            $0
                        }
                    }
                }
            }

            @usableFromInline
            @_lifetime(copy self)
            mutating func parsedStringContentAndTrailingQuote() throws(JSONError) -> ParsedString {
                // Assume easy path first -- no escapes, no characters requiring escapes.
                let startIndex = self.readOffset
                var foundEndOfString = false
                var foundBackslash = false

                ReadLoop:
                while true {
                    let byte = try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter()
                    guard _fastPath(byte & 0xe0 != 0) else {
                        // TODO: Wrong index.
                        // TODO: This doesn't work any more, since the offsets don't translate.
                        throw JSONError.unescapedControlCharacterInString(ascii: byte, location: .countingLinesAndColumns(upTo: readOffset, in: bytes))
                    }
                    switch byte {
                    case ._backslash:
                        moveReaderIndex(forwardBy: 1)
                        foundBackslash = true
                        break ReadLoop
                    case ._quote:
                        moveReaderIndex(forwardBy: 1)
                        foundEndOfString = true
                        break ReadLoop
                    default: break
                    }
                }

                let firstSectionSubspan = bytes.extracting(unchecked: startIndex..<readOffset-1)
                let firstSectionUTF8Span: UTF8Span
                do {
                    firstSectionUTF8Span = try UTF8Span(validating: .init(_bytes: firstSectionSubspan))
                } catch {
                    // TODO: This source location doesn't work any more.
                    throw .cannotConvertInputStringDataToUTF8(location: .countingLinesAndColumns(upTo: startIndex, in: bytes))
                }
                
                if foundEndOfString {
                    // Fast path with no escapes to deal with.
                    return .span(firstSectionUTF8Span)
                }
                
                guard foundBackslash else {
                    throw .unexpectedEndOfFile
                }
                
                let firstStringChunk = String(copying: firstSectionUTF8Span)
                var buffer = UniqueArray<UInt8>()

                // Parse the escape sequence, then keep looping.
                try _parseEscapeSequence(into: &buffer)
                try _slowpath_continueParsingString(into: &buffer)

                do {
                    // TODO: Creation of the String should be deferred until we know that the DecodingField or DecodingStringVisitor client wants a `String`. We could easily just give them the UTF8Span (or byte span?) instead.
                    let utf8Span = try UTF8Span(validating: buffer.span)
                    let output = firstStringChunk + String(copying: utf8Span)
                    
                    let subspan = bytes.extracting(unchecked: Range(uncheckedBounds: (startIndex, readOffset-1)))
                    let fullContentsSpan = UTF8Span(unchecked: .init(_bytes: subspan))
                    return .string(output, fullContentsSpan)
                } catch {
                    // TODO: This source location doesn't work any more.
                    throw .cannotConvertInputStringDataToUTF8(location: .countingLinesAndColumns(upTo: startIndex, in: bytes))

                }
            }

            // TODO: De-deuplicate this.
            @_lifetime(copy self)
            mutating func parseStringContentAndTrailingQuote(_ output: inout String) throws(JSONError) -> RawSpan {
                // Assume easy path first -- no escapes, no characters requiring escapes.
                let startIndex = self.readOffset
                var foundEndOfString = false
                var foundBackslash = false

                ReadLoop:
                while true {
                    let byte = try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter()
                    guard _fastPath(byte & 0xe0 != 0) else {
                        // TODO: Wrong index.
                        // TODO: This doesn't work any more, since the offsets don't translate.
                        throw JSONError.unescapedControlCharacterInString(ascii: byte, location: .countingLinesAndColumns(upTo: readOffset, in: bytes))
                    }
                    switch byte {
                    case ._backslash:
                        moveReaderIndex(forwardBy: 1)
                        foundBackslash = true
                        break ReadLoop
                    case ._quote:
                        moveReaderIndex(forwardBy: 1)
                        foundEndOfString = true
                        break ReadLoop
                    default: break
                    }
                }

                guard let firstStringChunk = String._tryFromUTF8(bytes.extracting(unchecked: startIndex..<readOffset-1)) else {
                    throw JSONError.cannotConvertInputStringDataToUTF8(location: .countingLinesAndColumns(upTo: startIndex, in: bytes))
                }

                if foundEndOfString {
                    output = firstStringChunk
                    return bytes.extracting(unchecked: startIndex..<readOffset-1)
                }
                
                guard foundBackslash else {
                    throw JSONError.unexpectedEndOfFile
                }
                
                var remainingBytes = UniqueArray<UInt8>()

                // Parse the escape sequence, then keep looping.
                try _parseEscapeSequence(into: &remainingBytes)
                try _slowpath_continueParsingString(into: &remainingBytes)
                
                do {
                    let utf8Span = try UTF8Span(validating: remainingBytes.span)
                    output = firstStringChunk + String(copying: utf8Span)
                    return bytes.extracting(unchecked: startIndex..<readOffset-1)
                } catch {
                    fatalError("TODO: error")
                }
            }

            // MARK: Numbers

            // ASCII constants, named for clarity:
            @inlinable
            var _0: UInt8 { 48 }
            @inlinable
            var numericalUpperBound: UInt8 { _0 &+ 10 }

            @usableFromInline @frozen
            enum IntegerParseResult<Result: FixedWidthInteger> {
                case pureInteger(Result)
                case retryAsFloatingPoint
                case notANumber
            }

            @inlinable
            internal mutating func _scanRestOfNumberFindingExponent() -> Bool {
                // "Simple" imprecise scan, since we're either throwing an error anyway, or retrying parse as floating point.
                var hasExponent = false
                while let char = peek() {
                    switch char {
                    case ._e, ._E:
                        hasExponent = true
                        fallthrough
                    case _0 ..< numericalUpperBound, ._dot, ._plus, ._minus:
                        moveReaderIndex(forwardBy: 1)
                    default: break
                    }
                }
                return hasExponent
            }

            @inlinable
            @inline(__always)
            @_lifetime(self: copy self)
            internal mutating func _parseIntegerDigits<Result: FixedWidthInteger>(isNegative: Bool) throws(JSONError) -> IntegerParseResult<Result> {
                let startOffset = readOffset
                guard let firstDigit = read() else {
                    throw JSONError.unexpectedEndOfFile
                }

                var result: Result
                if _fastPath(firstDigit > _0 && firstDigit < numericalUpperBound) {
                    result = Result(truncatingIfNeeded: firstDigit &- _0)
                    if isNegative {
                        result &*= -1
                    }
                } else if firstDigit == _0 {
                    // Leading zero. No more digits should follow.
                    switch peek() {
                    case .none:
                        return .pureInteger(0)
                    case (_0 ..< _0 + numericalUpperBound)?:
                        throw JSONError.numberWithLeadingZero(location: .countingLinesAndColumns(upTo: startOffset, in: bytes))
                    case ._dot, ._e, ._E:
                        self.readOffset = startOffset
                        return .retryAsFloatingPoint
                    default:
                        return .pureInteger(0)
                    }
                } else if firstDigit == ._dot || firstDigit == ._e || firstDigit == ._E {
                    self.readOffset = startOffset
                    return .retryAsFloatingPoint
                } else {
                    // This doesn't look like it's a number at all. Rewind.
                    self.readOffset = startOffset
                    return .notANumber
                }

                let multiplicand: Result = 10
                while let digit = peek() {
                    let digitValue: Result
                    if _fastPath(digit >= _0 && digit < numericalUpperBound) {
                        moveReaderIndex(forwardBy: 1)
                        digitValue = Result(truncatingIfNeeded: digit &- _0)
                    } else if digit == ._dot {
                        self.readOffset = startOffset
                        return .retryAsFloatingPoint
                    } else if digit == ._e || digit == ._E {
                        self.readOffset = startOffset
                        return .retryAsFloatingPoint
                    } else {
                        break
                    }

                    let overflow1: Bool
                    (result, overflow1) = result.multipliedReportingOverflow(by: multiplicand)
                    let overflow2: Bool
                    (result, overflow2) = isNegative
                    ? result.subtractingReportingOverflow(digitValue)
                    : result.addingReportingOverflow(digitValue)
                    guard _fastPath(!overflow1 && !overflow2) else {

                        // We overflowed, but if this is actually a floating point number, then with negative exponents, it could still be represented as this integer type. Scan forward for possible periods in this number.
                        if _scanRestOfNumberFindingExponent() {
                            return .retryAsFloatingPoint
                        }

                        // TODO: Bad `!`
                        let string = String._tryFromUTF8(bytes.extracting(startOffset ..< readOffset))!
                        throw JSONError.numberIsNotRepresentableInSwift(parsed: string)
                    }
                }
                // TODO: Investigate weeeird numbers being returned here in Twitter parse!
                return .pureInteger(result)
            }

            @inlinable
            @inline(__always)
            @_lifetime(self: copy self)
            mutating func parseInteger<Result: FixedWidthInteger>(as _: Result.Type) throws(JSONError) -> IntegerParseResult<Result> {
                switch peek() {
                case ._minus:
                    moveReaderIndex(forwardBy: 1)
                    return try _parseIntegerDigits(isNegative: true)
                case ._plus:
                    moveReaderIndex(forwardBy: 1)
                    fallthrough
                default:
                    return try _parseIntegerDigits(isNegative: false)
                }
            }

            @usableFromInline
            static func isTrueZero(_ buffer: borrowing RawSpan) -> Bool {
                var remainingBuffer = copy buffer

                // Non-zero numbers are allowed after 'e'/'E'. Since the format is already validated at this stage, we can stop scanning as soon as we see one.
                let nonZeroRange = UInt8(ascii: "1") ... UInt8(ascii: "9")

                @inline(__always)
                func check(_ off: Int, in buffer: borrowing RawSpan) -> Bool? {
                    switch buffer._loadByteUnchecked(off) {
                    case nonZeroRange: return false
                    case UInt8(ascii: "e"), UInt8(ascii: "E"): return true
                    default: return nil
                    }
                }

                // Manual loop unrolling.
                while remainingBuffer.byteCount >= 4 {
                    if let res = check(0, in: remainingBuffer) { return res }
                    if let res = check(1, in: remainingBuffer) { return res }
                    if let res = check(2, in: remainingBuffer) { return res }
                    if let res = check(3, in: remainingBuffer) { return res }

                    remainingBuffer = remainingBuffer.extracting(droppingFirst: 4)
                }

                // Process any remaining bytes in the same way.
                switch remainingBuffer.byteCount {
                case 3:
                    if let res = check(2, in: remainingBuffer) { return res }
                    fallthrough
                case 2:
                    if let res = check(1, in: remainingBuffer) { return res }
                    fallthrough
                case 1:
                    if let res = check(0, in: remainingBuffer) { return res }
                    break
                default:
                    break
                }

                return true
            }

            @inlinable
            @_lifetime(self: copy self)
            mutating func parseFloatingPoint<Result: BinaryFloatingPoint & PrevalidatedJSONNumberBufferConvertible>(as _: Result.Type) throws(JSONError) -> Result {
                let startIndex = readOffset
                let (_, hasExponent) = skipNumber()
                let endIndex = readOffset
                
                if isEOF {
                    // Create a null-terminated buffer for the number, since we need a non-number byte after it.
                    let numberLength = endIndex &- startIndex
                    
                    // Allocate buffer with space for the partial number + null terminator
                    let nullTerminatedBuffer = UnsafeMutableRawBufferPointer.allocate(
                        byteCount: numberLength + 1,
                        alignment: 1
                    )
                    defer {
                        nullTerminatedBuffer.deallocate()
                    }
                    
                    // Copy the partial number data
                    let span = bytes.extracting(unchecked: startIndex..<endIndex)
                    span.withUnsafeBytes(nullTerminatedBuffer.copyMemory(from:))
                    
                    // Add null terminator
                    nullTerminatedBuffer[numberLength] = 0
                    
                    let nullTerminatedSpan = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(nullTerminatedBuffer)).extracting(first: numberLength)
                    return try Self.parseFloatingPointFromBuffer(nullTerminatedSpan, hasExponent: hasExponent, originalSource: bytes)
                } else {
                    // We can safely parse from the original buffer, because we know it has a non-number byte after it.
                    let numberBuffer = bytes.extracting(startIndex ..< endIndex)
                    return try Self.parseFloatingPointFromBuffer(numberBuffer, hasExponent: hasExponent, originalSource: bytes)
                }
            }
            
            @inlinable
            internal static func parseFloatingPointFromBuffer<Result: BinaryFloatingPoint & PrevalidatedJSONNumberBufferConvertible>(
                _ numberBuffer: RawSpan,
                hasExponent: Bool,
                originalSource: RawSpan
            ) throws(JSONError) -> Result {
                // CHECK: Buffer is empty. Looks like a number.
                // NOTE: numberBuffer may not be a subrange of originalSource!
                let digitsStartOffset = try Self.prevalidateJSONNumber(from: numberBuffer, hasExponent: hasExponent, fullSource: originalSource)

                if let floatingPoint = Result(prevalidatedBuffer: numberBuffer) {
                    // Check for overflow (which results in an infinite result), or rounding to zero.
                    // While strtod does set ERANGE in the either case, we don't rely on it because setting errno to 0 first and then check the result is surprisingly expensive. For values "rounded" to infinity, we reject those out of hand. For values "rounded" down to zero, we perform check for any non-zero digits in the input, which turns out to be much faster.
                    if floatingPoint.isFinite {
                        guard floatingPoint != 0 || Self.isTrueZero(numberBuffer) else {
                            throw JSONError.numberIsNotRepresentableInSwift(parsed: String._tryFromUTF8(numberBuffer) ?? "bad string")
                        }
                        return floatingPoint
                    } else {
                        throw JSONError.numberIsNotRepresentableInSwift(parsed: String._tryFromUTF8(numberBuffer) ?? "bad string")
                    }
                }
                throw Self.validateNumber(from: numberBuffer.extracting(unchecked: digitsStartOffset..<numberBuffer.byteCount), fullSource: originalSource, expectingFailure: true)!
            }

            static func validateLeadingZero(in jsonBytes: borrowing RawSpan, fullSource: borrowing RawSpan) throws(JSONError) {
                // Leading zeros are very restricted.
                if jsonBytes.isEmpty {
                    // Yep, this is valid.
                    return
                }
                switch jsonBytes._loadByteUnchecked(0) {
                case UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
                    // This is valid after a leading zero.
                    return
                case _asciiNumbers:
                    // TODO: This doesn't work any more, since the offsets don't translate.
                    throw JSONError.numberWithLeadingZero(location: .countingLinesAndColumns(upTo: 0, in: fullSource))
                case let byte: // default
                    throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .countingLinesAndColumns(upTo: 0, in: fullSource))
                }
            }

            @usableFromInline
            static func prevalidateJSONNumber(
                from jsonBytes: borrowing RawSpan, hasExponent: Bool, fullSource: borrowing RawSpan
            ) throws(JSONError) -> Int {
                // Just make sure we (A) don't have a leading zero, and (B) We have at least one digit.
                guard !jsonBytes.isEmpty else {
                    preconditionFailure("Why was this function called, if there is no 0...9 or -")
                }
                let firstDigitOffset : Int
                switch jsonBytes._loadByteUnchecked(0) {
                case UInt8(ascii: "0"):
                    try validateLeadingZero(in: jsonBytes.extracting(droppingFirst: 1), fullSource: fullSource)
                    firstDigitOffset = 0
                case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                    firstDigitOffset = 0
                case UInt8(ascii: "-"):
                    guard jsonBytes.byteCount > 1 else {
                        // TODO: This doesn't work any more, since the offsets don't translate.
                        throw JSONError.unexpectedCharacter(context: "at end of number", ascii: UInt8(ascii: "-"), location: .countingLinesAndColumns(upTo: 0, in: fullSource))
                    }
                    switch jsonBytes._loadByteUnchecked(1) {
                    case UInt8(ascii: "0"):
                        try validateLeadingZero(in: jsonBytes.extracting(droppingFirst: 2), fullSource: fullSource)
                    case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                        // Good, we need at least one digit following the '-'
                        break
                    case let byte: // default
                        // Any other character is invalid.
                        // TODO: This doesn't work any more, since the offsets don't translate.
                        throw JSONError.unexpectedCharacter(context: "after '-' in number", ascii: byte, location: .countingLinesAndColumns(upTo: 1, in: fullSource))
                    }
                    firstDigitOffset = 1
                default:
                    preconditionFailure("Why was this function called, if there is no 0...9 or -")
                }

                // If the number was found to have an exponent, we have to guarantee that there are digits preceding it, which is a JSON requirement. If we don't, then our floating point parser, which is tolerant of that construction, will succeed and not produce the required error.
                if hasExponent {
                    var offset = firstDigitOffset &+ 1
                    exponentLoop: while offset < jsonBytes.byteCount {
                        switch jsonBytes._loadByteUnchecked(offset) {
                        case UInt8(ascii: "e"), UInt8(ascii: "E"):
                            let previous = offset &- 1
                            guard case _asciiNumbers = jsonBytes._loadByteUnchecked(previous) else {
                                // TODO: This doesn't work any more, since the offsets don't translate.
                                throw JSONError.unexpectedCharacter(context: "in number", ascii: jsonBytes._loadByteUnchecked(offset), location: .countingLinesAndColumns(upTo: offset, in: fullSource))
                            }
                            // We're done iterating.
                            break exponentLoop
                        default:
                            offset &+= 1
                        }
                    }
                }

                let lastOffset = jsonBytes.byteCount - 1
                assert(lastOffset >= 0)
                switch jsonBytes._loadByteUnchecked(lastOffset) {
                case _asciiNumbers:
                    break // In JSON, all numbers must end with a digit.
                case let lastByte: // default
                    // TODO: This doesn't work any more, since the offsets don't translate.
                    throw JSONError.unexpectedCharacter(context: "at end of number", ascii: lastByte, location: .countingLinesAndColumns(upTo: lastOffset, in: fullSource))
                }
                return firstDigitOffset
            }

            @usableFromInline
            static func validateNumber(from jsonBytes: borrowing RawSpan, fullSource: borrowing RawSpan, expectingFailure: Bool) -> JSONError? {
                enum ControlCharacter {
                    case operand
                    case decimalPoint
                    case exp
                    case expOperator
                }
                
                var offset = 0
                let endOffset = jsonBytes.byteCount
                // Fast-path, assume all digits.
                while offset < endOffset {
                    guard _asciiNumbers.contains(jsonBytes._loadByteUnchecked(offset)) else { break }
                    offset &+= 1
                }
                
                var pastControlChar: ControlCharacter = .operand
                var digitsSinceControlChar = offset
                
                // parse everything else
                while offset < endOffset {
                    let byte = jsonBytes._loadByteUnchecked(offset)
                    switch byte {
                    case _asciiNumbers:
                        digitsSinceControlChar += 1
                    case UInt8(ascii: "."):
                        guard digitsSinceControlChar > 0, pastControlChar == .operand else {
                            // TODO: This doesn't work any more, since the offsets don't translate.
                            return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .countingLinesAndColumns(upTo: offset, in: fullSource))
                        }
                        pastControlChar = .decimalPoint
                        digitsSinceControlChar = 0
                        
                    case UInt8(ascii: "e"), UInt8(ascii: "E"):
                        guard digitsSinceControlChar > 0,
                              pastControlChar == .operand || pastControlChar == .decimalPoint
                        else {
                            // TODO: This doesn't work any more, since the offsets don't translate.
                            return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .countingLinesAndColumns(upTo: offset, in: fullSource))
                        }
                        pastControlChar = .exp
                        digitsSinceControlChar = 0
                        
                    case UInt8(ascii: "+"), UInt8(ascii: "-"):
                        guard digitsSinceControlChar == 0, pastControlChar == .exp else {
                            return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .countingLinesAndColumns(upTo: offset, in: fullSource))
                        }
                        pastControlChar = .expOperator
                        digitsSinceControlChar = 0
                        
                    default:
                        return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .countingLinesAndColumns(upTo: offset, in: fullSource))
                    }
                    offset &+= 1
                }
                
                if expectingFailure {
                    if digitsSinceControlChar > 0 {
                        preconditionFailure("Invalid number expected in \(#function). Input code unit buffer contained valid input.")
                    } else { // prevalidateJSONNumber() already checks for trailing `e`/`E` characters.
                        preconditionFailure("Found trailing non-digit. Number character buffer was not validated with prevalidateJSONNumber()")
                    }
                }
                
                return nil
            }

            @discardableResult
            @inlinable
            mutating func skipNumber() -> (containsDecimal: Bool, containsExponent: Bool) {
                guard let ascii = read() else {
                    preconditionFailure("Why was this function called, if there is no 0...9 or -")
                }
                switch ascii {
                case _asciiNumbers, UInt8(ascii: "-"):
                    break
                default:
                    preconditionFailure("Why was this function called, if there is no 0...9 or -")
                }
                
                var containsDecimal = false
                var containsExponent = false
            Loop:
                while let byte = peek() {
                    if _fastPath(_asciiNumbers.contains(byte)) {
                        moveReaderIndex(forwardBy: 1)
                        continue
                    }
                    switch byte {
                    case UInt8(ascii: "."):
                        containsDecimal = true
                        fallthrough
                    case UInt8(ascii: "+"), UInt8(ascii: "-"):
                        moveReaderIndex(forwardBy: 1)
                    case UInt8(ascii: "e"), UInt8(ascii: "E"):
                        moveReaderIndex(forwardBy: 1)
                        containsExponent = true
                    default:
                        break Loop
                    }
                }
                return (containsDecimal, containsExponent)
            }

            @inlinable
            internal static func u64ContainsQuoteBackslashOrInvalidCharacters(_ u64: UInt64) -> Bool {
                let bits: UInt64 =
                (
                    ( u64 &- 0x2020202020202020 as UInt64 ) |
                    ( (u64 ^ (UInt64(UInt8._quote) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64) |
                    ( (u64 ^ (UInt64(UInt8._backslash) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64)
                )
                & 0x8080808080808080
    //            print("0x\(String(u64, radix: 16)) ", bits != 0 ? "does" : "does NOT", " contain quote, backslash, or invalid characters")
                return bits != 0
            }

            @inlinable
            internal static func u64MaskeddBitsForQuoteBackslashOrInvalidCharacters(_ u64: UInt64) -> UInt64 {
                let bits: UInt64 = ~u64 &
                (
                    ( u64 &- 0x2020202020202020 as UInt64 ) |
                    ( (u64 ^ (UInt64(UInt8._quote) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64) |
                    ( (u64 ^ (UInt64(UInt8._backslash) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64)
                )
                & 0x8080808080808080
    //            print("0x\(String(u64, radix: 16)) ", bits != 0 ? "does" : "does NOT", " contain quote, backslash, or invalid characters")
                return bits
            }

            @_alwaysEmitIntoClient
            @inlinable
            internal mutating func skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter() throws(JSONError) -> UInt8 {
                guard let first = peek() else {
                    throw .unexpectedEndOfFile
                }
                guard first != ._backslash, first != ._quote else {
                    return first
                }

                while let u64 = peek(as: UInt64.self) {
                    let maskedBits = Self.u64MaskeddBitsForQuoteBackslashOrInvalidCharacters(u64)
                    if maskedBits == 0 {
                        self.moveReaderIndex(forwardBy: MemoryLayout<UInt64>.stride)
                    } else {
                        let bytesToSkip = maskedBits.trailingZeroBitCount / 8
                        self.moveReaderIndex(forwardBy: bytesToSkip)
                        return bytes._loadByteUnchecked(readOffset)
                    }
                }

                return try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter_slow()
            }

            @usableFromInline
            @inline(never)
            internal mutating func skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter_slow() throws(JSONError) -> UInt8 {
                while let byte = self.peek() {
                    switch byte {
                    case ._quote, ._backslash:
                        return byte
                    default:
                        // Any control characters in the 0-31 range are invalid. Any other characters will have at least one bit in a 0xe0 mask.
                        guard _fastPath(byte & 0xe0 != 0) else {
                            return byte
                        }
                        self.moveReaderIndex(forwardBy: 1)
                    }
                }
                throw .unexpectedEndOfFile
            }

            @inlinable
            internal static func u64ContainsQuoteOrBackslash(_ u64: UInt64) -> Bool {
                let bits: UInt64 =
                (
                    ( (u64 ^ (UInt64(UInt8._quote) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64) |
                    ( (u64 ^ (UInt64(UInt8._backslash) * (0x0101010101010101 as UInt64))) &- 0x0101010101010101 as UInt64)
                )
                & 0x8080808080808080
    //            print("0x\(String(u64, radix: 16)) ", bits != 0 ? "does" : "does NOT", " contain quote, backslash, or invalid characters")
                return bits != 0
            }

            @inlinable
            internal mutating func skipUTF8StringTillQuoteOrBackslash() throws(JSONError) -> UInt8 {
                guard let first = peek() else {
                    throw JSONError.unexpectedEndOfFile
                }
                guard first != ._backslash, first != ._quote else {
                    return first
                }

                while let u64 = self.peek(as: UInt64.self) {
                    if Self.u64ContainsQuoteOrBackslash(u64) {
                        break
                    }
                    self.moveReaderIndex(forwardBy: MemoryLayout<UInt64>.stride)
                }

                while let byte = self.peek() {
                    switch byte {
                    case ._quote, ._backslash:
                        return byte
                    default:
                        self.moveReaderIndex(forwardBy: 1)
                    }
                }
                throw JSONError.unexpectedEndOfFile
            }

            @inlinable
            internal mutating func skipEscapeSequence() throws(JSONError) {
                let firstChar = self.read()
                assert(firstChar == ._backslash, "Expected to have a backslash first")

                guard let ascii = self.read() else {
                    throw JSONError.unexpectedEndOfFile
                }

                // Invalid escaped characters checking deferred to parse time.
                if ascii == UInt8(ascii: "u") {
                    try skipUnicodeHexSequence()
                }
            }

            @usableFromInline
            @inline(__always)
            internal static func noByteMatches(_ asciiByte: UInt8, in hexString: UInt32) -> Bool {
                assert(asciiByte & 0x80 == 0)
                // Copy asciiByte of interest to mask.
                let t0 = UInt32(0x01010101) &* UInt32(asciiByte)
                // xor input and mask, then locate potential matches.
                let t1 = ((hexString ^ t0) & 0x7f7f7f7f) &+ 0x7f7f7f7f
                // Positions with matches are 0x7f.
                // Positions with non-matching ascii bytes have their MSB set.
                // Positions with non-ascii bytes do not have their MSB set.
                // Eliminate non-ascii bytes with a bitwise-or of t1 with the input,
                // then select the positions whose MSB is not set.
                let t2 = ((hexString | t1) & 0x80808080) ^ 0x80808080
                // There is no match when no bit is set.
                return t2 == 0
            }

            @inlinable
            internal mutating func skipUnicodeHexSequence() throws(JSONError) {
                // As stated in RFC-8259 an escaped unicode character is 4 HEXDIGITs long
                // https://tools.ietf.org/html/rfc8259#section-7
                try requireRemainingBytes(4)

                // We'll validate the actual characters following the '\u' escape during parsing. Just make sure that the string doesn't end prematurely.
                let hs = bytes.unsafeLoadUnaligned(fromUncheckedByteOffset: readOffset, as: UInt32.self)
                guard Self.noByteMatches(UInt8(ascii: "\""), in: hs) else {
                    let hexString = _withUnprotectedUnsafeBytes(of: hs) { String(decoding: $0, as: UTF8.self) }
                    throw JSONError.invalidHexDigitSequence(hexString, location: sourceLocation)
                }
                self.moveReaderIndex(forwardBy: 4)
            }

            @inlinable
            mutating func skipUTF8StringTillNextUnescapedQuote() throws(JSONError) {
                // If there aren't any escapes, then this is a simple case and we can exit early.
                while try skipUTF8StringTillQuoteOrBackslash() == ._backslash {
                    try skipEscapeSequence()
                }
                // Either we hit EOF and an error was already thrown, or we hit an unescaped quote, and we're done.
                return
            }
        }

    }
}

extension JSONParserDecoder.ParserState.DocumentReader {
    @inline(__always)
    func expectBeginningOfObject(_ ascii: UInt8) throws(JSONError) {
        guard ascii == ._openbrace else {
            throw JSONError.unexpectedCharacter(context: "at beginning of object", ascii: ascii, location: self.sourceLocation)
        }
    }
    
    // Returns false if end of object is found
    @discardableResult
    @inline(__always)
    func expectBeginningOfObjectKey(_ ascii: UInt8, orEndOfObjectAfterTrailingQuote allowEndOfObject: Bool = false) throws(JSONError) -> Bool {
        switch ascii {
        case ._quote:
            return true
        case ._closebrace:
            if allowEndOfObject {
                return false
            }
            fallthrough
        default:
            throw JSONError.unexpectedCharacter(context: "at beginning of object key", ascii: ascii, location: self.sourceLocation)
        }
    }
    
    @inline(__always)
    func expectObjectKeyValueColon(_ ascii: UInt8) throws(JSONError) {
        guard ascii == ._colon else {
            throw JSONError.unexpectedCharacter(context: "in between object key and value", ascii: ascii, location: self.sourceLocation)
        }
    }
    
    @inline(__always)
    func expectBeginningOfArray(_ ascii: UInt8) throws(JSONError) {
        guard ascii == ._openbracket else {
            throw JSONError.unexpectedCharacter(context: "at beginning of array", ascii: ascii, location: self.sourceLocation)
        }
    }
    
    @inline(__always)
    func expectArrayComma(_ ascii: UInt8) throws(JSONError) {
        guard ascii == ._comma else {
            throw JSONError.unexpectedCharacter(context: "in between array values", ascii: ascii, location: self.sourceLocation)
        }
    }
}

extension JSONParserDecoder.ParserState {
    func typeDescription(primitive: JSONPrimitive) -> String {
        switch primitive {
        case .string: "string"
        case .dictionary: "object"
        case .array: "array"
        case .bool: "boolean"
        case .null: "null"
        case .number: "number"
        }
    }
    
    @usableFromInline
    func decodingError(expectedTypeDescription: String) -> CodingError.Decoding {
        var decoder = JSONParserDecoder(state: self)
        do {
            let primitive = try decoder.decodeJSONPrimitive()
            return CodingError.typeMismatch(expectedTypeDescription: expectedTypeDescription, actualValueDescription: typeDescription(primitive: primitive), at: self.codingPath)
        } catch {
            return error
        }
    }
}
