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

internal struct JSONWriter: ~Copyable, ~Escapable {
    
    // Structures with container nesting deeper than this limit are not valid.
    private static var maximumRecursionDepth: Int { 512 }
    
    private var indent = 0
    private let pretty: Bool
    private let escapeTable: StaticString
    private let escapeLengths: [UInt8]
    
    var data: GrowableEncodingBytes
    
    @_lifetime(immortal)
    internal init(pretty: Bool, withoutEscapingSlashes: Bool) {
        self.data = .init()
        self.pretty = pretty
        if withoutEscapingSlashes {
            self.escapeTable = Self.escapeTable
            self.escapeLengths = Self.escapeLens
        } else {
            self.escapeTable = Self.escapeTableWithEscapedForwardSlash
            self.escapeLengths = Self.escapeLensWithEscapedForwardSlash
        }
    }
    
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func write(_ string: StaticString) {
        write(pointer: string.utf8Start, count: string.utf8CodeUnitCount)
    }
    
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func write(contentsOf sequence: some Sequence<UInt8>) {
        let done: Void? = sequence.withContiguousStorageIfAvailable {
            self.write(buffer: RawSpan(_unsafeElements: $0))
        }
        if done != nil { return }
        self.write(slowpathContentsOf: sequence)
    }
    
    @inline(never)
    @_lifetime(self: copy self)
    mutating func write(slowpathContentsOf sequence: some Sequence<UInt8>) {
        for byte in sequence {
            self.write(ascii: byte)
        }
    }
    
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func write(ascii: UInt8) {
        data.append(ascii)
    }
    
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func write(pointer: UnsafePointer<UInt8>, count: Int) {
        self.write(buffer: RawSpan(_unsafeStart: pointer, count: count))
    }
    
    //    @inline(__always)
    @_lifetime(self: copy self)
    mutating func write(buffer: RawSpan) {
        data.append(buffer)
    }
    
    // Shortcut for strings known not to require escapes, like numbers.
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func serializeSimpleStringContentsSpan(_ span: UTF8Span) {
        write(buffer: span.span.bytes)
    }
    
    // Shortcut for strings known not to require escapes, like numbers.
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func serializeSimpleStringContentsSpan(_ span: Span<UInt8>) {
        write(buffer: span.bytes)
    }
    
    // Shortcut for strings known not to require escapes, like numbers.
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func serializeSimpleStringContents(_ str: String) {
        // TODO: watchOS/32-bit
        return serializeSimpleStringContentsSpan(str.utf8Span)
    }
    
    // Shortcut for strings known not to require escapes, like numbers.
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func serializeSimpleString(_ str: String) {
        write(ascii: ._quote)
        defer {
            write(ascii: ._quote)
        }
        self.serializeSimpleStringContents(str)
    }
    
    static let escapeTable: StaticString = """
    \\u0000\0 \\u0001\0 \\u0002\0 \\u0003\0 \
    \\u0004\0 \\u0005\0 \\u0006\0 \\u0007\0 \
    \\b\0     \\t\0     \\n\0     \\u000b\0 \
    \\f\0     \\r\0     \\u000e\0 \\u000f\0 \
    \\u0010\0 \\u0011\0 \\u0012\0 \\u0013\0 \
    \\u0014\0 \\u0015\0 \\u0016\0 \\u0017\0 \
    \\u0018\0 \\u0019\0 \\u001a\0 \\u001b\0 \
    \\u001c\0 \\u001d\0 \\u001e\0 \\u001f\0 \
     \0      !\0      \\\"\0     #\0      \
    $\0      %\0      &\0      '\0      \
    (\0      )\0      *\0      +\0      \
    ,\0      -\0      .\0      /\0      \
    0\0      1\0      2\0      3\0      \
    4\0      5\0      6\0      7\0      \
    8\0      9\0      :\0      ;\0      \
    <\0      =\0      >\0      ?\0      \
    @\0      A\0      B\0      C\0      \
    D\0      E\0      F\0      G\0      \
    H\0      I\0      J\0      K\0      \
    L\0      M\0      N\0      O\0      \
    P\0      Q\0      R\0      S\0      \
    T\0      U\0      V\0      W\0      \
    X\0      Y\0      Z\0      [\0      \
    \\\\\0     ]\0      ^\0      _\0      
    """
    
    static let escapeTableWithEscapedForwardSlash: StaticString = """
    \\u0000\0 \\u0001\0 \\u0002\0 \\u0003\0 \
    \\u0004\0 \\u0005\0 \\u0006\0 \\u0007\0 \
    \\b\0     \\t\0     \\n\0     \\u000b\0 \
    \\f\0     \\r\0     \\u000e\0 \\u000f\0 \
    \\u0010\0 \\u0011\0 \\u0012\0 \\u0013\0 \
    \\u0014\0 \\u0015\0 \\u0016\0 \\u0017\0 \
    \\u0018\0 \\u0019\0 \\u001a\0 \\u001b\0 \
    \\u001c\0 \\u001d\0 \\u001e\0 \\u001f\0 \
     \0      !\0      \\\"\0     #\0      \
    $\0      %\0      &\0      '\0      \
    (\0      )\0      *\0      +\0      \
    ,\0      -\0      .\0      \\/\0     \
    0\0      1\0      2\0      3\0      \
    4\0      5\0      6\0      7\0      \
    8\0      9\0      :\0      ;\0      \
    <\0      =\0      >\0      ?\0      \
    @\0      A\0      B\0      C\0      \
    D\0      E\0      F\0      G\0      \
    H\0      I\0      J\0      K\0      \
    L\0      M\0      N\0      O\0      \
    P\0      Q\0      R\0      S\0      \
    T\0      U\0      V\0      W\0      \
    X\0      Y\0      Z\0      [\0      \
    \\\\\0     ]\0      ^\0      _\0      
    """
    
    static let escapeLens: [UInt8] = [
        6, 6, 6, 6,
        6, 6, 6, 6,
        2, 2, 2, 6,
        2, 2, 6, 6,
        6, 6, 6, 6,
        6, 6, 6, 6,
        6, 6, 6, 6,
        6, 6, 6, 6,
        0, 0, 2, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        2, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]
    
    static let escapeLensWithEscapedForwardSlash: [UInt8] = [
        6, 6, 6, 6,
        6, 6, 6, 6,
        2, 2, 2, 6,
        2, 2, 6, 6,
        6, 6, 6, 6,
        6, 6, 6, 6,
        6, 6, 6, 6,
        6, 6, 6, 6,
        0, 0, 2, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 2,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        2, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]
    
    @inline(__always)
    func escapeLength(for byte: UInt8) -> Int {
        let byteInt = Int(byte)
        let escapeLen = self.escapeLengths[byteInt]
        return Int(escapeLen)
    }
    
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func writeEscape(byte: UInt8, length: Int) {
        var ptr = self.escapeTable.utf8Start
        ptr += 8 * Int(byte)
        self.write(pointer: ptr, count: length)
    }
    
    @_lifetime(self: copy self)
    mutating func serializeStringContentsSpan(_ span: UTF8Span) {
        if span.isEmpty {
            return
        }
        
        @inline(__always)
        func appendAccumulatedBytes(in span: Span<UInt8>, from mark: Int, to cursor: Int) {
            if cursor > mark {
                let subspan = span.extracting(unchecked: mark ..< cursor)
                write(buffer: subspan.bytes)
            }
        }
        
        // This had better constant-fold
        @inline(__always)
        func oneBytes<T: FixedWidthInteger>() -> T {
            var result: T = 0
            var shift = 0
            while shift < T.bitWidth {
                result |= 0x01 << shift
                shift &+= UInt8.bitWidth
            }
            return result
        }
        
        @inline(__always)
        func bytesBeforeEscape<T: FixedWidthInteger>(input: T) -> Int {
            var ones: T { oneBytes() }
            var spaces: T { ones &* T(UInt8._space) }
            var quotes: T { ones &* T(UInt8._quote) }
            var slashes: T { ones &* T(UInt8._slash) }
            var backslashes: T { ones &* T(UInt8._backslash) }
            var mask_msb: T { ones &* 0x80 }
            
            // Escape control characters (< 0x20).
            let hasControlChars = input &- spaces
            let hasQuotes = (input ^ quotes) &- ones
            let hasSlashes = (input ^ slashes) &- ones
            let hasBackslashes = (input ^ backslashes) &- ones
            // Chars >= 0x7F don't need escaping.
            let result_mask = ~input & mask_msb
            let result = ((hasControlChars | hasQuotes | hasSlashes | hasBackslashes) & result_mask)
            return result.trailingZeroBitCount / 8
        }
        
        @inline(__always)
        func needsEscape<T: FixedWidthInteger>(input: T) -> Bool {
            var ones: T { oneBytes() }
            var spaces: T { ones &* T(UInt8._space) }
            var quotes: T { ones &* T(UInt8._quote) }
            var slashes: T { ones &* T(UInt8._slash) }
            var backslashes: T { ones &* T(UInt8._backslash) }
            var mask_msb: T { ones &* 0x80 }
            
            // Escape control characters (< 0x20).
            let hasControlChars = input &- spaces
            let hasQuotes = (input ^ quotes) &- ones
            let hasSlashes = (input ^ slashes) &- ones
            let hasBackslashes = (input ^ backslashes) &- ones
            // Chars >= 0x7F don't need escaping.
            let result_mask = ~input & mask_msb
            let result = ((hasControlChars | hasQuotes | hasSlashes | hasBackslashes) & result_mask)
            return result != 0
        }
        
        @inline(__always)
        func writeNonEscapingCharacters_SIMD(in span: Span<UInt8>, from cursor: inout Int) {
            let start = cursor
            let end = span.count
            if (end &- cursor) > MemoryLayout<SIMD16<UInt8>>.size * 2 { // Only do SIMD if we have at least two vectors worth.
                let spaces = SIMD16<UInt8>(repeating: ._space)
                let quotes = SIMD16<UInt8>(repeating: ._quote)
                let slash = SIMD16<UInt8>(repeating: ._slash)
                let backslash = SIMD16<UInt8>(repeating: ._backslash)
                
                let packedDistance = MemoryLayout<SIMD16<UInt8>>.size
                while (end &- cursor) > packedDistance {
                    let input = span.bytes.unsafeLoadUnaligned(fromUncheckedByteOffset: cursor, as: SIMD16<UInt8>.self)
                    let hasControlChars = input .< spaces
                    let hasQuotes = input .== quotes
                    let hasSlashes = input .== slash
                    let hasBackslashes = input .== backslash
                    let result = hasControlChars .| hasQuotes .| hasSlashes .| hasBackslashes
                    if any(result) == false {
                        cursor &+= packedDistance
                        continue
                    } else {
                        let bitcast = unsafeBitCast(result, to: UInt128.self)
                        let zeroBytes = bitcast.trailingZeroBitCount / 8
                        cursor &+= zeroBytes
                        break
                    }
                }
            }
            let len = cursor &- start
            if len > 0 {
                appendAccumulatedBytes(in: span, from: start, to: cursor)
            }
        }
        
        @inline(__always)
        func skipNonEscapingCharacters_SWAR(in span: Span<UInt8>, at cursor: inout Int) -> Bool {
            do {
                let packedDistance = MemoryLayout<UInt64>.size
                if (span.count &- cursor) >= packedDistance {
                    let integer = span.bytes.unsafeLoadUnaligned(fromUncheckedByteOffset: cursor, as: UInt64.self)
                    let bytesBeforeEscape = bytesBeforeEscape(input: integer)
                    cursor &+= bytesBeforeEscape
                    return bytesBeforeEscape == MemoryLayout<UInt64>.size
                }
            }
            
            do {
                let packedDistance = MemoryLayout<UInt32>.size
                if (span.count &- cursor) >= packedDistance {
                    let integer = span.bytes.unsafeLoadUnaligned(fromUncheckedByteOffset: cursor, as: UInt32.self)
                    let bytesBeforeEscape = bytesBeforeEscape(input: integer)
                    cursor &+= bytesBeforeEscape
                    return bytesBeforeEscape == MemoryLayout<UInt32>.size
                }
            }
            
            return false
        }

        @inline(__always)
        func processByte(in span: Span<UInt8>, at cursor: inout Int, mark: inout Int) {
            let byte = span[unchecked: cursor]
            let escapeLen = escapeLength(for: byte)
            if escapeLen > 0 {
                appendAccumulatedBytes(in: span, from: mark, to: cursor)
                writeEscape(byte: byte, length: escapeLen)
                cursor &+= 1
                mark = cursor
            } else {
                // Accumulate byte
                cursor &+= 1
            }
        }
        
        let byteSpan = span.span
        var idx = 0
        writeNonEscapingCharacters_SIMD(in: byteSpan, from: &idx)
        
        let count = byteSpan.count
        var mark = idx
        while idx < count {
            if skipNonEscapingCharacters_SWAR(in: byteSpan, at: &idx) {
                continue
            }
            
            processByte(in: byteSpan, at: &idx, mark: &mark)
        }
        appendAccumulatedBytes(in: byteSpan, from: mark, to: idx)
    }
    
    @_lifetime(self: copy self)
    mutating func serializeStringContentsSpanNoEscapes(_ span: UTF8Span) {
        if span.isEmpty {
            return
        }
        self.write(buffer: span.span.bytes)
    }
    
    @_lifetime(self: copy self)
    mutating func serializeString(_ str: String, checkForEscapes: Bool) {
        // TODO: watchOS/32-bit
        serializeStringSpan(str.utf8Span, checkForEscapes: checkForEscapes)
    }
    
    @_lifetime(self: copy self)
    mutating func serializeStringSpan(_ str: borrowing UTF8Span, checkForEscapes: Bool) {
        write(ascii: ._quote)
        defer {
            write(ascii: ._quote)
        }
        if checkForEscapes {
            return self.serializeStringContentsSpan(str)
        } else {
            return self.serializeStringContentsSpanNoEscapes(str)
        }
    }
    
    @_lifetime(self: copy self)
    mutating func prepareForArray(depth: Int) throws(JSONError) {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }
        
        write(ascii: ._openbracket)
    }
    
    @_lifetime(self: copy self)
    mutating func prepareForArrayElement(first: Bool) {
        if pretty {
            if first {
                write(ascii: ._newline)
                incIndent()
            } else {
                write(contentsOf: [._comma, ._newline])
            }
            writeIndent()
        } else if !first {
            write(ascii: ._comma)
        }
    }
    
    @_lifetime(self: copy self)
    mutating func finishArray() {
        if pretty {
            write(ascii: ._newline)
            decAndWriteIndent()
        }
        write(ascii: ._closebracket)
    }
    
    @_lifetime(self: copy self)
    mutating func prepareForObject(depth: Int) throws(JSONError) {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }
        
        self.write(ascii: ._openbrace)
        if pretty {
            self.write(ascii: ._newline)
            incIndent()
        }
    }
    
    @_lifetime(self: copy self)
    mutating func prepareForObjectKey(first: Bool) {
        if pretty {
            if !first {
                self.write(contentsOf: [._comma, ._newline])
            }
            writeIndent()
        } else if !first {
            self.write(ascii: ._comma)
        }
    }
    
    @_lifetime(self: copy self)
    mutating func prepareForObjectValue() {
        if pretty {
            self.write(contentsOf: [._space, ._colon, ._space])
        } else {
            self.write(ascii: ._colon)
        }
    }
    
    @_lifetime(self: copy self)
    mutating func finishObject() {
        if pretty {
            self.write(ascii: ._newline)
            decAndWriteIndent()
        }
        self.write(ascii: ._closebrace)
    }
    
    @_lifetime(self: copy self)
    mutating func incIndent() {
        indent &+= 1
    }
    
    @_lifetime(self: copy self)
    mutating func incAndWriteIndent() {
        indent &+= 1
        writeIndent()
    }
    
    @_lifetime(self: copy self)
    mutating func decAndWriteIndent() {
        indent &-= 1
        writeIndent()
    }
    
    @_lifetime(self: copy self)
    mutating func writeIndent() {
        switch indent {
        case 0:  break
        case 1:  self.write("  ")
        case 2:  self.write("    ")
        case 3:  self.write("      ")
        case 4:  self.write("        ")
        case 5:  self.write("          ")
        case 6:  self.write("            ")
        case 7:  self.write("              ")
        case 8:  self.write("                ")
        case 9:  self.write("                  ")
        case 10: self.write("                    ")
        default:
            for _ in 0..<indent {
                self.write("  ")
            }
        }
    }
}
