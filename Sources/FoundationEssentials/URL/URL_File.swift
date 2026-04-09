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

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

private extension UnsafeMutableBufferPointer<UInt8> {
    @inline(__always)
    func initialize(fromContentsOf source: StaticString) -> Index {
        let sourceLength = source.utf8CodeUnitCount
        precondition(self.count >= sourceLength)
        guard sourceLength > 0 else { return startIndex }
        // Precondition: self.count > 0
        baseAddress.unsafelyUnwrapped.initialize(
            from: source.utf8Start, count: sourceLength
        )
        return startIndex.advanced(by: sourceLength)
    }
}

extension URL {

    /// Updates `pathBuffer` for directory trailing-slash handling, returning the
    /// new path length. May append a trailing slash for directories or trim trailing
    /// slashes for non-directories.
    ///
    /// - Precondition: `currentLength < pathBuffer.count` when a trailing slash must be appended
    static func finalPathLength(
        updating pathBuffer: UnsafeMutableBufferPointer<UInt8>,
        currentLength: Int,
        flags: inout _URLFlags,
        isDirectory: Bool
    ) -> Int {
        guard currentLength > 0 else {
            return 0
        }
        var pathLength = currentLength
        if isDirectory {
            flags.insert(.hasDirectoryPath)
            // Append a trailing "/" if one doesn't exist already
            // Precondition: pathLength > 0
            assert(pathLength > 0)
            if pathBuffer[pathLength - 1] != UInt8(ascii: "/") {
                precondition(pathLength < pathBuffer.count)
                pathBuffer[pathLength] = UInt8(ascii: "/")
                pathLength += 1
            }
        } else if pathLength == 1 && pathBuffer[0] == UInt8(ascii: "/") {
            // Override isDirectory if the path is to root
            flags.insert(.hasDirectoryPath)
        } else {
            // Not a directory, remove all trailing slashes except root
            let rootLength = rootLength(pathBuffer: UnsafeBufferPointer(pathBuffer), length: pathLength)
            while pathLength > rootLength && pathBuffer[pathLength - 1] == UInt8(ascii: "/") {
                pathLength -= 1
            }
        }
        return pathLength
    }

    /// Parses a finalized file system representation `path` into a URL string by:
    /// 1) prepending a `"file://"` scheme if the path is absolute
    /// 2) percent-encoding any invalid characters in the path
    ///
    /// - Note: All trailing-slash adjustments must already be applied to `path`,
    ///   see `finalPathLength(updating:currentLength:flags:isDirectory)`.
    static func parseFinalFileSystemRepresentation(
        path: borrowing Span<UInt8>,
        flags: inout _URLFlags,
        encodeSemicolons: Bool
    ) -> String {
        guard path.count > 0 else {
            return ""
        }
        // Note: don't insert .hasOldNetLocation, which only considers a non-empty authority
        var isAbsolute = true
        if path.starts(with: "/.file/id=") {
            flags.insert([.hasScheme, .hasHost, .isFileURL, .isFileReferenceURL, .hasSpecialScheme])
        } else if path.first == UInt8(ascii: "/") {
            flags.insert([.hasScheme, .hasHost, .isFileURL, .hasSpecialScheme])
        } else {
            // We don't know if this is a file URL without checking the base
            isAbsolute = false
        }

        let filePrefix: StaticString = "file://"

        // Return the full (maybe percent-encoded) URL string
        var maxEncodedSize = 3 * path.count
        if isAbsolute {
            maxEncodedSize += filePrefix.utf8CodeUnitCount
        }
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxEncodedSize) { encodedBuffer in
            var pathStart = 0
            if isAbsolute {
                pathStart = encodedBuffer.initialize(fromContentsOf: filePrefix)
            }
            let bytesWritten = path.withUnsafeBufferPointer { pathBuffer in
                URLEncoder.percentEncodeUnchecked(
                    input: pathBuffer,
                    output: .init(rebasing: encodedBuffer[pathStart...]),
                    // Encode ";" for CF/NSURL (encodeSemicolons: true)
                    component: encodeSemicolons ? .pathNoSemicolon : .path,
                    skipAlreadyEncoded: false
                )
            }
            if bytesWritten != path.count {
                // The path was percent-encoded
                flags.insert(.hasEncodedPath)
            }
            return String(decoding: encodedBuffer[..<(pathStart + bytesWritten)], as: UTF8.self)
        }
    }

    static func parseUTF8Path(_ path: String, flags: inout _URLFlags, isDirectory: Bool, encodeSemicolons: Bool) -> String {
        var path = path
        return path.withUTF8 { pathBuffer in
            // Allocate an extra byte in case we need to append a directory slash.
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: pathBuffer.count + 1) {
                let pathLength = finalPathLength(
                    updating: $0,
                    currentLength: $0.initialize(fromContentsOf: pathBuffer),
                    flags: &flags,
                    isDirectory: isDirectory
                )
                let path = $0.span.extracting(first: pathLength)
                return parseFinalFileSystemRepresentation(path: path, flags: &flags, encodeSemicolons: encodeSemicolons)
            }
        }
    }

    static func parsePOSIXPath(_ path: String, flags: inout _URLFlags, isDirectory: Bool) -> String {
        var path = path
        _ = URL.isAbsolute(standardizing: &path, pathStyle: .posix)
        #if FOUNDATION_FRAMEWORK
        #if !os(watchOS)
        if path.utf8Span.isKnownASCII {
            return parseUTF8Path(path, flags: &flags, isDirectory: isDirectory, encodeSemicolons: false)
        }
        #endif
        // Convert path to its decomposed file system representation
        let maxFSRSize = path.maxFileSystemRepresentationSize
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxFSRSize + 1) { pathBuffer in
            if var pathLength = path._decomposed(.hfsPlus, into: pathBuffer) {
                // _decomposed(_:into:) already checks for embedded null bytes,
                // but includes trailing null bytes in the returned length.
                while pathLength > 0 && pathBuffer[pathLength - 1] == 0 {
                    pathLength -= 1
                }
                let finalLength = finalPathLength(
                    updating: pathBuffer,
                    currentLength: pathLength,
                    flags: &flags,
                    isDirectory: isDirectory
                )
                let path = pathBuffer.span.extracting(first: finalLength)
                return parseFinalFileSystemRepresentation(path: path, flags: &flags, encodeSemicolons: false)
            }

            // Decomposition failed or there was an embedded null byte.
            // Since the URL file path initializers are non-failable, be lenient:
            // 1) encode "\0" to "%00" if present (will never be decoded)
            // 2) use the UTF8 bytes instead of the file system representation

            // Encoding the null makes the API misuse visible and debuggable, and
            // while the using the UTF8 bytes on decomposition failure might lead
            // to a "file not found" error, this is more practical and debuggable
            // than returning an empty URL or crashing with fatalError().

            return parseUTF8Path(path, flags: &flags, isDirectory: isDirectory, encodeSemicolons: false)
        }
        #else
        return parseUTF8Path(path, flags: &flags, isDirectory: isDirectory, encodeSemicolons: false)
        #endif
    }

    static func parseWindowsPath(_ path: String, flags: inout _URLFlags, isDirectory: Bool) -> String {
        var path = path.replacing(._backslash, with: ._slash)
        // Standardizes an absolute path like "C:/" to "/C:/"
        _ = URL.isAbsolute(standardizing: &path, pathStyle: .windows)
        guard !path.isEmpty else {
            return ""
        }
        return parseUTF8Path(path, flags: &flags, isDirectory: isDirectory, encodeSemicolons: false)
    }
}
