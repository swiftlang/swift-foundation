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
@_spi(_Unicode) import Swift
internal import Foundation_Private.NSString
#endif

#if canImport(Darwin)
import Darwin
#endif

#if os(Windows)
import WinSDK

extension String {
    package func withNTPathRepresentation<Result>(_ body: (UnsafePointer<WCHAR>) throws -> Result) throws -> Result {
        guard !isEmpty else {
            throw CocoaError.errorWithFilePath(.fileReadInvalidFileName, "")
        }

        var iter = self.utf8.makeIterator()
        let bLeadingSlash = if [._slash, ._backslash].contains(iter.next()), iter.next()?.isLetter ?? false, iter.next() == ._colon { true } else { false }

        // Strip the leading `/` on a RFC8089 path (`/[drive-letter]:/...` ).  A
        // leading slash indicates a rooted path on the drive for the current
        // working directory.
        return try Substring(self.utf8.dropFirst(bLeadingSlash ? 1 : 0)).withCString(encodedAs: UTF16.self) { pwszPath in
            // 1. Normalize the path first.
            let dwLength: DWORD = GetFullPathNameW(pwszPath, 0, nil, nil)
            return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
                guard GetFullPathNameW(pwszPath, DWORD($0.count), $0.baseAddress, nil) > 0 else {
                    throw CocoaError.errorWithFilePath(self, win32: GetLastError(), reading: true)
                }

                // 2. Perform the operation on the normalized path.
                return try body($0.baseAddress!)
            }
        }
    }
}
#endif

extension String {
    package func _trimmingWhitespace() -> String {
        if self.isEmpty {
            return ""
        }
        
        return String(unicodeScalars._trimmingCharacters {
            $0.properties.isWhitespace
        })
    }

    package init?(_utf16 input: UnsafeBufferPointer<UInt16>) {
        // Allocate input.count * 3 code points since one UTF16 code point may require up to three UTF8 code points when transcoded
        let str = withUnsafeTemporaryAllocation(of: UTF8.CodeUnit.self, capacity: input.count * 3) { contents in
            var count = 0
            let error = transcode(input.makeIterator(), from: UTF16.self, to: UTF8.self, stoppingOnError: true) { codeUnit in
                contents[count] = codeUnit
                count += 1
            }

            guard !error else {
                return nil as String?
            }

            return String._tryFromUTF8(UnsafeBufferPointer(rebasing: contents[..<count]))
        }

        guard let str else {
            return nil
        }
        self = str
    }

    package init?(_utf16 input: UnsafeMutableBufferPointer<UInt16>, count: Int) {
        guard let str = String(_utf16: UnsafeBufferPointer(rebasing: input[..<count])) else {
            return nil
        }
        self = str
    }

    package init?(_utf16 input: UnsafePointer<UInt16>, count: Int) {
        guard let str = String(_utf16: UnsafeBufferPointer(start: input, count: count)) else {
            return nil
        }
        self = str
    }
    
    enum _NormalizationType {
        case canonical
        case hfsPlus
        
        fileprivate var setType: BuiltInUnicodeScalarSet.SetType {
            switch self {
            case .canonical: .canonicalDecomposable
            case .hfsPlus: .hfsPlusDecomposable
            }
        }
    }
    
    private func _decomposed(_ type: String._NormalizationType, into buffer: UnsafeMutableBufferPointer<UInt8>, nullTerminated: Bool = false) -> Int? {
        var copy = self
        return copy.withUTF8 {
            try? $0._decomposed(type, as: Unicode.UTF8.self, into: buffer, nullTerminated: nullTerminated)
        }
    }
    
    #if canImport(Darwin) || FOUNDATION_FRAMEWORK
    fileprivate func _fileSystemRepresentation(into buffer: UnsafeMutableBufferPointer<CChar>) -> Bool {
        let result = buffer.withMemoryRebound(to: UInt8.self) { rebound in
            _decomposed(.hfsPlus, into: rebound, nullTerminated: true)
        }
        return result != nil
    }
    
    private var maxFileSystemRepresentationSize: Int {
        // The Darwin file system representation expands the UTF-8 contents to decomposed UTF-8 contents (only decomposing specific scalars)
        // For any given scalar that we decompose, we will increase its UTF-8 length by at most a factor of 3 during decomposition
        // (ex. U+0390 expands from 2 to 6 UTF-8 code-units, U+1D160 expands from 4 to 12 UTF-8 code-units)
        // Therefore in the worst case scenario, the result will be the UTF-8 length multiplied by a factor of 3 plus an additional byte for the null byte
        self.utf8.count * 3 + 1
    }
    #endif
    
    package func withFileSystemRepresentation<R>(_ block: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        #if canImport(Darwin) || FOUNDATION_FRAMEWORK
        try withUnsafeTemporaryAllocation(of: CChar.self, capacity: maxFileSystemRepresentationSize) { buffer in
            guard _fileSystemRepresentation(into: buffer) else {
                return try block(nil)
            }
            return try block(buffer.baseAddress!)
        }
        #else
#if os(Windows)
        var iter = self.utf8.makeIterator()
        let bLeadingSlash = if iter.next() == ._slash, iter.next()?.isLetter ?? false, iter.next() == ._colon { true } else { false }
        // Strip the leading `/` on a RFC8089 path (`/[drive-letter]:/...` ).  A
        // leading slash indicates a rooted path on the drive for the current
        // working directory.
        return try Substring(self.utf8.dropFirst(bLeadingSlash ? 1 : 0)).replacing(._slash, with: ._backslash).withCString {
            try block($0)
        }
#else
        return try withCString {
            try block($0)
        }
#endif
        #endif
    }
    
    package func withMutableFileSystemRepresentation<R>(_ block: (UnsafeMutablePointer<CChar>?) throws -> R) rethrows -> R {
        #if canImport(Darwin) || FOUNDATION_FRAMEWORK
        try withUnsafeTemporaryAllocation(of: CChar.self, capacity: maxFileSystemRepresentationSize) { buffer in
            guard _fileSystemRepresentation(into: buffer) else {
                return try block(nil)
            }
            return try block(buffer.baseAddress!)
        }
        #else
#if os(Windows)
        var iter = self.utf8.makeIterator()
        let bLeadingSlash = if iter.next() == ._slash, iter.next()?.isLetter ?? false, iter.next() == ._colon { true } else { false }
        var mut: String =
            Substring(self.utf8[self.utf8.index(self.utf8.startIndex, offsetBy: bLeadingSlash ? 1 : 0)...])
                .replacing(._slash, with: ._backslash)
#else
        var mut: String = self
#endif

        return try mut.withUTF8 { utf8Buffer in
            // Leave space for a null byte at the end
            try withUnsafeTemporaryAllocation(of: CChar.self, capacity: utf8Buffer.count + 1) { temporaryBuffer in
                try utf8Buffer.withMemoryRebound(to: CChar.self) { utf8CCharBuffer in
                    let nullByteIndex = temporaryBuffer.initialize(fromContentsOf: utf8CCharBuffer)
                    // Null-terminate
                    temporaryBuffer.initializeElement(at: nullByteIndex, to: CChar(0))
                    let result = try block(temporaryBuffer.baseAddress)
                    temporaryBuffer.prefix(through: nullByteIndex).deinitialize()
                    return result
                }
            }
        }
        #endif
    }

}

extension UnsafeBufferPointer {
    private enum DecompositionError : Error {
        case insufficientSpace
        case illegalScalar
        case decodingError
    }
    
    fileprivate func _decomposedRebinding<T: UnicodeCodec, InputElement>(_ type: String._NormalizationType, as codec: T.Type, into buffer: UnsafeMutableBufferPointer<InputElement>, nullTerminated: Bool = false) throws -> Int {
        try self.withMemoryRebound(to: T.CodeUnit.self) { reboundSelf in
            try buffer.withMemoryRebound(to: Unicode.UTF8.CodeUnit.self) { reboundBuffer in
                try reboundSelf._decomposed(type, as: codec, into: reboundBuffer, nullTerminated: nullTerminated)
            }
        }
    }
    
    fileprivate func _decomposed<T: UnicodeCodec>(_ type: String._NormalizationType, as codec: T.Type, into buffer: UnsafeMutableBufferPointer<UInt8>, nullTerminated: Bool = false) throws -> Int where Element == T.CodeUnit {
        let scalarSet = BuiltInUnicodeScalarSet(type: type.setType)
        var bufferIdx = 0
        let bufferLength = buffer.count
        var sortBuffer: [UnicodeScalar] = []
        var seenNullIdx: Int? = nil
        var decoder = T()
        var iterator = self.makeIterator()
        
        guard !buffer.isEmpty else {
            if !nullTerminated && iterator.next() == nil {
                // No bytes to write, so an empty buffer is OK
                return 0
            } else {
                throw DecompositionError.insufficientSpace
            }
        }
        
        defer {
            if nullTerminated {
                // Ensure buffer is always null-terminated even on failure to prevent buffer over-reads
                // At this point, the buffer is known to be non-empty, so it must have space for at least a null terminating byte (even if it overwrites the final output byte in the buffer)
                if bufferIdx < bufferLength {
                    // We still have space left in the buffer - if we haven't already null-terminated then add a null byte to the buffer
                    // Since we have space, we only want to write the null byte when/where we have to since some clients provide buffer sizes that don't match the true buffer length
                    if bufferIdx == buffer.startIndex || buffer[bufferIdx - 1] != 0 {
                        buffer[bufferIdx] = 0
                    }
                } else {
                    // The buffer is non-empty but we've completely filled it, overwrite the last written byte with a null byte to ensure null termination
                    buffer[buffer.count - 1] = 0
                }
            }
        }
        
        func appendOutput(_ values: some Collection<UInt8>) throws {
            let bufferPortion = UnsafeMutableBufferPointer(start: buffer.baseAddress!.advanced(by: bufferIdx), count: bufferLength - bufferIdx)
            guard bufferPortion.count >= values.count else {
                throw DecompositionError.insufficientSpace
            }
            bufferIdx += bufferPortion.initialize(fromContentsOf: values)
        }
        
        func appendOutput(_ value: UInt8) throws {
            guard bufferIdx < bufferLength else {
                throw DecompositionError.insufficientSpace
            }
            buffer.initializeElement(at: bufferIdx, to: value)
            bufferIdx += 1
        }
        
        func encodedScalar(_ scalar: UnicodeScalar) throws -> some Collection<UInt8> {
            guard let encoded = UTF8.encode(scalar) else {
                throw DecompositionError.illegalScalar
            }
            return encoded
        }
        
        func fillFromSortBuffer() throws {
            guard !sortBuffer.isEmpty else { return }
            sortBuffer.sort {
                $0.properties.canonicalCombiningClass.rawValue < $1.properties.canonicalCombiningClass.rawValue
            }
            for scalar in sortBuffer {
                try appendOutput(encodedScalar(scalar))
            }
            sortBuffer.removeAll(keepingCapacity: true)
        }
        
        decodingLoop: while bufferIdx < bufferLength {
            var scalar: UnicodeScalar
            switch decoder.decode(&iterator) {
            // We've finished the input, return the index
            case .emptyInput: break decodingLoop
            case .error: throw DecompositionError.decodingError
            case .scalarValue(let v): scalar = v
            }
            
            if scalar.value == 0 {
                // Null bytes within the string are fine as long as they are at the end
                seenNullIdx = bufferIdx
            } else if seenNullIdx != nil {
                // File system representations are c-strings that do not support embedded null bytes
                throw DecompositionError.illegalScalar
            }
            
            let isASCII = scalar.isASCII
            if isASCII || scalar.properties.canonicalCombiningClass == .notReordered {
                try fillFromSortBuffer()
            }

            if isASCII {
                try appendOutput(UInt8(scalar.value))
            } else {
#if FOUNDATION_FRAMEWORK
                // Only decompose scalars present in the declared set
                if scalarSet.contains(scalar) {
                    sortBuffer.append(contentsOf: String(scalar)._nfd)
                } else {
                    // Even if a scalar isn't decomposed, it may still need to be re-ordered
                    sortBuffer.append(scalar)
                }
#else
                // TODO: Implement Unicode decomposition in swift-foundation
                sortBuffer.append(scalar)
#endif
            }
        }
        try fillFromSortBuffer()
        
        if iterator.next() != nil {
            throw DecompositionError.insufficientSpace
        } else {
            if let seenNullIdx {
                return seenNullIdx + 1
            }
            if nullTerminated {
                try appendOutput(0)
            }
            return bufferIdx
        }
    }
}

#if FOUNDATION_FRAMEWORK
@objc
extension NSString {
    @objc
    func __swiftFillFileSystemRepresentation(pointer: UnsafeMutablePointer<CChar>, maxLength: Int) -> Bool {
        autoreleasepool {
            let buffer = UnsafeMutableBufferPointer(start: pointer, count: maxLength)
            
            guard !buffer.isEmpty else {
                // No space for a null terminating byte, so it's not worth even trying to read the string contents
                return false
            }
            
            // See if we have a quick-access buffer we can just convert directly
            if let fastCharacters = self._fastCharacterContents() {
                // If we have quick access to UTF-16 contents, decompose from UTF-16
                let charsBuffer = UnsafeBufferPointer(start: fastCharacters, count: self.length)
                return (try? charsBuffer._decomposedRebinding(.hfsPlus, as: Unicode.UTF16.self, into: buffer, nullTerminated: true)) != nil
            } else if self.fastestEncoding == NSASCIIStringEncoding, let fastUTF8 = self._fastCStringContents(false) {
                // If we have quick access to ASCII contents, no need to decompose
                let utf8Buffer = UnsafeBufferPointer(start: fastUTF8, count: self.length)
                
                // We only allow embedded nulls if there are no non-null characters following the first null character
                if let embeddedNullIdx = utf8Buffer.firstIndex(of: 0) {
                    if !utf8Buffer[embeddedNullIdx...].allSatisfy({ $0 == 0 }) {
                        // Ensure the buffer is always null-terminated even on failure to prevent buffer over-reads - at this point we know the buffer is non-empty
                        buffer[0] = 0
                        return false
                    }
                }
                
                var (leftoverIterator, next) = buffer.initialize(from: utf8Buffer)
                guard leftoverIterator.next() == nil && next < buffer.endIndex else {
                    // Ensure the buffer is always null-terminated even on failure to prevent buffer over-reads
                    buffer[buffer.endIndex - 1] = 0
                    return false
                }
                buffer[next] = 0
                return true
            } else {
                // Otherwise, bridge to a String which will create a UTF-8 buffer
                return String(self)._fileSystemRepresentation(into: buffer)
            }
        }
    }
}
#endif
