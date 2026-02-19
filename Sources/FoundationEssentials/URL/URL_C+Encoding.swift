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

// MARK: - NSURL extensions for CF/NSURL percent-encoding

// Many CFURL percent-encoding use-cases require skipping valid percent-escapes
// that are already in the string, e.g. "%20 %20" becomes "%20%20%20". However,
// some use-cases, such as encoding a file path or path component to append,
// will encode everything, including the "%" in a valid percent-escape.

@objc
extension NSURL {

    // MARK: Encoding entry points

    static func __copySwiftEncodedUser(_ original: String, encoding: CFStringEncoding) -> String? {
        guard encoding != CFStringBuiltInEncodings.UTF8.rawValue else {
            return URLEncoder.percentEncode(string: original, component: .user, skipAlreadyEncoded: true)
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentEncode(string: original, encoding: encoding, component: .user, skipAlreadyEncoded: true)
    }

    static func __copySwiftEncodedPassword(_ original: String, encoding: CFStringEncoding) -> String? {
        guard encoding != CFStringBuiltInEncodings.UTF8.rawValue else {
            return URLEncoder.percentEncode(string: original, component: .password, skipAlreadyEncoded: true)
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentEncode(string: original, encoding: encoding, component: .password, skipAlreadyEncoded: true)
    }

    static func __copySwiftEncodedHost(_ original: String, encoding: CFStringEncoding) -> String? {
        guard encoding != CFStringBuiltInEncodings.UTF8.rawValue else {
            return URLEncoder.percentEncode(string: original, component: .host, skipAlreadyEncoded: true)
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentEncode(string: original, encoding: encoding, component: .host, skipAlreadyEncoded: true)
    }

    static func __copySwiftEncodedPath(_ original: String, encoding: CFStringEncoding) -> String? {
        guard encoding != CFStringBuiltInEncodings.UTF8.rawValue else {
            return URLEncoder.percentEncode(string: original, component: .path, skipAlreadyEncoded: true)
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentEncode(string: original, encoding: encoding, component: .path, skipAlreadyEncoded: true)
    }

    static func __copySwiftEncodedQuery(_ original: String, encoding: CFStringEncoding) -> String? {
        guard encoding != CFStringBuiltInEncodings.UTF8.rawValue else {
            return URLEncoder.percentEncode(string: original, component: .query, skipAlreadyEncoded: true)
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentEncode(string: original, encoding: encoding, component: .query, skipAlreadyEncoded: true)
    }

    static func __copySwiftEncodedFragment(_ original: String, encoding: CFStringEncoding) -> String? {
        guard encoding != CFStringBuiltInEncodings.UTF8.rawValue else {
            return URLEncoder.percentEncode(string: original, component: .fragment, skipAlreadyEncoded: true)
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentEncode(string: original, encoding: encoding, component: .fragment, skipAlreadyEncoded: true)
    }

    // MARK: Decoding entry points

    static func __copySwiftDecodedString(_ original: String) -> String? {
        return URLEncoder.percentDecode(string: original)
    }

    static func __copySwiftDecodedString(_ original: String, encoding: CFStringEncoding) -> String? {
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentDecode(string: original, encoding: encoding)
    }

    static func __copySwiftDecodedString(_ original: String, charactersToLeaveEscaped: String) -> String? {
        return URLEncoder.percentDecode(string: original, encoding: .utf8, excludingScalars: Set(charactersToLeaveEscaped.unicodeScalars))
    }

    static func __copySwiftDecodedString(_ original: String, encoding: CFStringEncoding, charactersToLeaveEscaped: String) -> String? {
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentDecode(string: original, encoding: encoding, excludingScalars: Array(charactersToLeaveEscaped.unicodeScalars))
    }

    // MARK: File path decoding and encoding

    static func __copySwiftDecodedFilePath(_ original: String) -> String? {
        return URLEncoder.percentDecode(string: original, excludingASCII: .posixPath)
    }

    static func __copySwiftEncodedPathComponent(_ path: String, encodeSlashes: Bool) -> String {
        let component: URLComponentAllowedMask = encodeSlashes ? .pathNoSemicolonNoSlash : .pathNoSemicolon
        return URLEncoder.percentEncode(string: path, component: component, skipAlreadyEncoded: false)
    }

    static func __copySwiftEncodedPathComponent(_ path: String, encodeSlashes: Bool, encoding: CFStringEncoding) -> String? {
        let component: URLComponentAllowedMask = encodeSlashes ? .pathNoSemicolonNoSlash : .pathNoSemicolon
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        return URLEncoder.percentEncode(string: path, encoding: encoding, component: component, skipAlreadyEncoded: false)
    }

    static func __copySwiftEncodedFSRPath(_ path: String) -> String? {
        guard !path.isEmpty else {
            return path
        }
        // Convert path to its decomposed file system representation then encode
        let maxFSRSize = 3 * path.utf8.count
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxFSRSize) { pathBuffer -> String? in
            guard var pathLength = path._decomposed(.hfsPlus, into: pathBuffer) else {
                return nil
            }
            // Strip trailing slashes up to the root prefix
            let rootLength = rootLength(pathBuffer: UnsafeBufferPointer(pathBuffer), length: pathLength)
            while pathLength > rootLength && pathBuffer[pathLength - 1] == UInt8(ascii: "/") {
                pathLength -= 1
            }
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 3 * pathLength) { encodedBuffer in
                let encodedLength = URLEncoder.percentEncodeUnchecked(
                    input: UnsafeBufferPointer(rebasing: pathBuffer[..<pathLength]),
                    output: encodedBuffer,
                    // Encode ";" for compatibility
                    component: .pathNoSemicolon,
                    skipAlreadyEncoded: false
                )
                return String(decoding: encodedBuffer[..<encodedLength], as: UTF8.self)
            }
        }
    }

    // MARK: file:// URL string decoding

    /// Decodes an absolute `file://` URL string that was potentially encoded
    /// from its file system representation. Returns just the POSIX path, stripping
    /// a trailing slash if present.
    ///
    /// - Note: Interprets the decoded file system representation as UTF8.
    static func __copySwiftPOSIXPath(forFileURLString string: String) -> String {
        assert(string.utf8.starts(with: "file://".utf8))
        var mut = string
        return mut.withUTF8 { buffer in
            let filePrefixSize = 7 // "file://"
            return String(unsafeUninitializedCapacity: buffer.count - filePrefixSize) { outputBuffer in
                guard let pathLength = URLEncoder.percentDecode(
                    input: UnsafeBufferPointer(rebasing: buffer[filePrefixSize...]),
                    output: outputBuffer
                ) else {
                    return 0
                }
                let rootLength = rootLength(
                    pathBuffer: UnsafeBufferPointer(outputBuffer),
                    length: pathLength
                )
                if pathLength > rootLength && outputBuffer[pathLength - 1] == UInt8(ascii: "/") {
                    // Strip the trailing slash
                    return pathLength - 1
                }
                return pathLength
            }
        }
    }

    /// Decodes an absolute `file://` URL string that was potentially encoded
    /// from its file system representation. Stores the null-terminated file system
    /// representation into `bufferPtr`.
    ///
    /// - Note: `removePercentEscapes: false` will skip percent-decoding.
    /// - Returns: `true` on success, `false` if decoding fails or there's not
    ///   enough room in the supplied buffer.
    static func __swiftDecodeFileURLString(_ string: String, intoFSR bufferPtr: UnsafeMutablePointer<UInt8>, length: Int, removePercentEscapes: Bool) -> Bool {
        assert(string.utf8.starts(with: "file://".utf8))
        guard length > 0 else {
            return false
        }
        let outputBuffer = UnsafeMutableBufferPointer(start: bufferPtr, count: length)
        var mut = string
        return mut.withUTF8 { buffer in
            let filePrefixSize = 7 // "file://"
            let pathLength: Int
            if removePercentEscapes {
                guard let decodedLength = URLEncoder.percentDecode(
                    input: UnsafeBufferPointer(rebasing: buffer[filePrefixSize...]),
                    output: outputBuffer
                ) else {
                    outputBuffer[0] = 0
                    return false
                }
                pathLength = decodedLength
            } else {
                guard outputBuffer.count >= buffer.count - filePrefixSize else {
                    outputBuffer[0] = 0
                    return false
                }
                pathLength = outputBuffer.initialize(
                    fromContentsOf: buffer[filePrefixSize...]
                )
            }
            // Null terminate the file system representation
            guard pathLength < length else {
                // No room for a null terminator, overwrite the last index
                outputBuffer[length - 1] = 0
                return false
            }
            let rootLength = rootLength(pathBuffer: UnsafeBufferPointer(outputBuffer), length: pathLength)
            if pathLength > rootLength && outputBuffer[pathLength - 1] == UInt8(ascii: "/") {
                // Strip the trailing slash by inserting null
                outputBuffer[pathLength - 1] = 0
            } else {
                outputBuffer[pathLength] = 0
            }
            return true
        }
    }
}

#endif
