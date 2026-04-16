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

#if FOUNDATION_FRAMEWORK

// MARK: - URL Span creation from CFStrings

// CFURL parsing uses either an 8-bit ASCII or 16-bit UTF16 buffer from the
// original CFString. The component CFRanges depend on this original encoding
// used for parsing, so when resolving relative and base URLs, both must use
// the same original buffer encoding to ensure these ranges are valid.

// When using stored component ranges, such as during relative URL resolution,
// callers should use _withURLSpan() or _withURLSpans() to match the original
// buffer encoding, or use CFStringCreateWithSubstring() directly.

internal func _withURLSpan<R>(
    string: CFString,
    blockIfASCII block8: (borrowing Span<Unicode.ASCII.CodeUnit>) -> R,
    blockIfUTF16 block16: (borrowing Span<UTF16.CodeUnit>) -> R
) -> R {
    let length = CFStringGetLength(string)
    if let ptr = CFStringGetCStringPtr(string, CFStringBuiltInEncodings.ASCII.rawValue) {
        return ptr.withMemoryRebound(to: UInt8.self, capacity: length) {
            return block8(Span(_unsafeStart: $0, count: length))
        }
    }

    if let ptr = CFStringGetCharactersPtr(string) {
        return block16(Span(_unsafeStart: ptr, count: length))
    }

    // (Hopefully) use a stack buffer that fits 99.9% of cases
    let bufferSize = 1024
    var neededLength = 0
    let range = CFRange(location: 0, length: length)
    let ascii = CFStringBuiltInEncodings.ASCII.rawValue

    // Pass nil buffer to get neededLength
    CFStringGetBytes(string, range, ascii, 0, false, nil, Int.max, &neededLength)

    // Note: all of the buffers below are non-zero size, so .baseAddress! is OK.
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: bufferSize) { buffer in
        if neededLength == length {
            // We can use a UInt8 buffer
            if length <= bufferSize {
                CFStringGetBytes(string, range, ascii, 0, false, buffer.baseAddress!, bufferSize, nil)
                return block8(Span(_unsafeStart: buffer.baseAddress!, count: length))
            }
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { allocatedBuffer in
                CFStringGetBytes(string, range, ascii, 0, false, allocatedBuffer.baseAddress!, length, nil)
                return block8(allocatedBuffer.span)
            }
        }
        // Get the UTF16 characters
        if 2 * length <= bufferSize {
            return buffer.withMemoryRebound(to: UInt16.self) { uint16Buffer in
                CFStringGetCharacters(string, range, uint16Buffer.baseAddress!)
                return block16(Span(_unsafeStart: uint16Buffer.baseAddress!, count: length))
            }
        }
        return withUnsafeTemporaryAllocation(of: UInt16.self, capacity: length) { uint16Buffer in
            CFStringGetCharacters(string, range, uint16Buffer.baseAddress!)
            return block16(uint16Buffer.span)
        }
    }
}

internal func _withURLSpans<R>(
    string1: CFString,
    string2: CFString,
    blockIfASCII block8: (borrowing Span<Unicode.ASCII.CodeUnit>, borrowing Span<Unicode.ASCII.CodeUnit>) -> R,
    blockIfUTF16 block16: (borrowing Span<UTF16.CodeUnit>, borrowing Span<UTF16.CodeUnit>) -> R
) -> R {
    return _withURLSpan(
        string: string1,
        blockIfASCII: { s1span8 in
            return _withURLSpan(
                string: string2,
                blockIfASCII: { s2span8 in
                    return block8(s1span8, s2span8)
                },
                blockIfUTF16: { s2span16 in
                    return withUnsafeTemporaryAllocation(of: UInt16.self, capacity: s1span8.count) { s1buffer16 in
                        // s1span8 is ASCII, which is the same in UTF16
                        // _withURLSpan gives us a 0-indexed Span.
                        assert(s1span8.indices.startIndex == 0)
                        for i in 0..<s1span8.count {
                            s1buffer16[i] = UInt16(s1span8[unchecked: i])
                        }
                        return block16(s1buffer16.span, s2span16)
                    }
                }
            )
        },
        blockIfUTF16: { s1span16 in
            return _withURLSpan(
                string: string2,
                blockIfASCII: { s2span8 in
                    return withUnsafeTemporaryAllocation(of: UInt16.self, capacity: s2span8.count) { s2buffer16 in
                        assert(s2span8.indices.startIndex == 0)
                        for i in 0..<s2span8.count {
                            s2buffer16[i] = UInt16(s2span8[unchecked: i])
                        }
                        return block16(s1span16, s2buffer16.span)
                    }
                },
                blockIfUTF16: { s2span16 in
                    return block16(s1span16, s2span16)
                }
            )
        }
    )
}

// MARK: - CFString creation from URL buffers

internal func _createCFStringFromASCIIBuffer(
    capacity: Int,
    initializingASCIIWith block: (UnsafeMutableBufferPointer<Unicode.ASCII.CodeUnit>) -> Int
) -> Unmanaged<CFString>? {
    return withUnsafeTemporaryAllocation(of: Unicode.ASCII.CodeUnit.self, capacity: capacity) { outputBuffer in
        let outputLength = block(outputBuffer)
        guard let string = CFStringCreateWithBytes(
            kCFAllocatorDefault,
            outputBuffer.baseAddress!,
            outputLength,
            CFStringBuiltInEncodings.ASCII.rawValue,
            false
        ) else {
            return nil
        }
        return Unmanaged<CFString>.passRetained(string)
    }
}

internal func _createCFStringFromCharacterBuffer(
    capacity: Int,
    initializingUTF16With block: (UnsafeMutableBufferPointer<UTF16.CodeUnit>) -> Int
) -> Unmanaged<CFString>? {
    return withUnsafeTemporaryAllocation(of: UTF16.CodeUnit.self, capacity: capacity) { outputBuffer in
        let outputLength = block(outputBuffer)
        guard let string = CFStringCreateWithCharacters(
            kCFAllocatorDefault,
            outputBuffer.baseAddress!,
            outputLength
        ) else {
            return nil
        }
        return Unmanaged<CFString>.passRetained(string)
    }
}

#endif // FOUNDATION_FRAMEWORK
