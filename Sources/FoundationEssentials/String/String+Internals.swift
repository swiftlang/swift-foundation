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
#endif

#if canImport(Darwin)
import Darwin
#endif

extension String {
    package func _trimmingWhitespace() -> String {
        String(unicodeScalars._trimmingCharacters {
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
    
    #if canImport(Darwin)
    fileprivate func _fileSystemRepresentation(into buffer: UnsafeMutableBufferPointer<CChar>) -> Bool {
        let result = buffer.withMemoryRebound(to: UInt8.self) { uintBuffer in
            let newBuffer = UnsafeMutableBufferPointer(start: uintBuffer.baseAddress, count: uintBuffer.count - 1)
            return _decomposed(.hfsPlus, into: newBuffer, nullTerminated: true)
        }
        
        return result != nil
    }
    #endif
    
    package func withFileSystemRepresentation<R>(_ block: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        #if canImport(Darwin)
        try withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(MAXPATHLEN)) { buffer in
            guard _fileSystemRepresentation(into: buffer) else {
                return try block(nil)
            }
            return try block(buffer.baseAddress!)
        }
        #else
        try self.withCString {
            try block($0)
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
        
        func appendOutput(_ values: some Sequence<UInt8>) throws {
            let bufferPortion = UnsafeMutableBufferPointer(start: buffer.baseAddress!.advanced(by: bufferIdx), count: bufferLength - bufferIdx)
            var (leftOver, idx) = bufferPortion.initialize(from: values)
            bufferIdx += idx
            if bufferIdx == bufferLength && leftOver.next() != nil {
                throw DecompositionError.insufficientSpace
            }
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
            if !isASCII && scalar.properties.canonicalCombiningClass != .notReordered {
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
            } else {
                if !sortBuffer.isEmpty {
                    sortBuffer.sort {
                        $0.properties.canonicalCombiningClass.rawValue < $1.properties.canonicalCombiningClass.rawValue
                    }
                    for scalar in sortBuffer {
                        try appendOutput(encodedScalar(scalar))
                    }
                    sortBuffer.removeAll(keepingCapacity: true)
                }
                
                if isASCII {
                    try appendOutput(UInt8(scalar.value))
                } else {
                    try appendOutput(encodedScalar(scalar))
                }
            }
        }
        
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
        let buffer = UnsafeMutableBufferPointer(start: pointer, count: maxLength)
        // See if we have a quick-access buffer we can just convert directly
        if let fastCharacters = self._fastCharacterContents() {
            // If we have quick access to UTF-16 contents, decompose from UTF-16
            let charsBuffer = UnsafeBufferPointer(start: fastCharacters, count: self.length)
            return (try? charsBuffer._decomposedRebinding(.hfsPlus, as: Unicode.UTF16.self, into: buffer, nullTerminated: true)) != nil
        } else if let fastUTF8 = self._fastCStringContents(true) {
            // If we have quick access to UTF-8 contents, decompose from UTF-8
            let utf8Buffer = UnsafeBufferPointer(start: fastUTF8, count: strlen(fastUTF8))
            if self.fastestEncoding == NSASCIIStringEncoding {
                // If this is an ASCII string, no need to decompose
                guard utf8Buffer.count < buffer.count else {
                    return false
                }
                let next = buffer.initialize(fromContentsOf: utf8Buffer)
                buffer[next] = 0
                return true
            } else {
                return (try? utf8Buffer._decomposedRebinding(.hfsPlus, as: Unicode.UTF8.self, into: buffer, nullTerminated: true)) != nil
            }
        } else {
            // Otherwise, bridge to a String which will create a UTF-8 buffer
            return String(self)._fileSystemRepresentation(into: buffer)
        }
    }
}
#endif
