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

internal import _ForSwiftFoundation

// MARK: - NSURL extensions for CF/NSURL file path handling

@objc
extension NSURL {

    // Returns true on success, false otherwise (indicating CFURL should return NULL).
    static func __swiftParseFilePath(_ path: Unmanaged<CFString>, into impl: UnsafeMutablePointer<__CFFileURLImpl>, pathStyle: CFURLPathStyle, isDirectory: Bool) -> Bool {
        var flags = __CFURLFlags.fileImplFlags
        let path = path.takeUnretainedValue()
        let urlString: String?
        switch pathStyle {
        case .cfurlposixPathStyle:
            urlString = parsePOSIX(path, flags: &flags, isDirectory: isDirectory)
        case .cfurlWindowsPathStyle:
            urlString = parseWindows(path as String, flags: &flags, isDirectory: isDirectory)
        case .cfurlhfsPathStyle:
            urlString = parseHFS(path as String, flags: &flags, isDirectory: isDirectory)
        default:
            assert(false, "Unexpected path style: \(pathStyle)")
            return false
        }
        guard let urlString else {
            return false
        }

        assert(flags.isDisjoint(with: .nonFileImplFlags))
        impl.pointee._header._flags = flags
        impl.pointee._header._string = Unmanaged<CFString>.passRetained(
            urlString as CFString
        )
        return true
    }

    // Returns true on success, false otherwise (indicating CFURL should return NULL).
    static func __swiftParseFileSystemRepresentation(_ fsr: UnsafePointer<UInt8>, length: Int, into impl: UnsafeMutablePointer<__CFFileURLImpl>, isDirectory: Bool) -> Bool {
        guard length > 0 else {
            return false
        }

        var flags = __CFURLFlags.fileImplFlags
        let buffer = UnsafeBufferPointer(start: fsr, count: length)
        guard let urlString = parseFileSystemRepresentation(buffer: buffer, flags: &flags, isDirectory: isDirectory) else {
            return false
        }

        assert(flags.isDisjoint(with: .nonFileImplFlags))
        impl.pointee._header._flags = flags
        impl.pointee._header._string = Unmanaged<CFString>.passRetained(
            urlString as CFString
        )
        return true
    }

    #if !NO_FILESYSTEM
    static func __copySwiftFilePath(forFileReferencePath path: String, resolveFlags: UInt32) -> String? {
        return filePath(for: path, resolveFlags: resolveFlags)
    }
    #endif

    static func __copySwiftFileSystemPath(forURLPath urlPath: String, encoding: CFStringEncoding, pathStyle: CFURLPathStyle, isFileURL: Bool) -> String? {
        guard !urlPath.isEmpty else {
            return urlPath
        }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
        switch pathStyle {
        case .cfurlposixPathStyle:
            return posixPath(urlPath: urlPath, encoding: encoding, isFileURL: isFileURL)
        case .cfurlWindowsPathStyle:
            return windowsPath(urlPath: urlPath, encoding: encoding)
        case .cfurlhfsPathStyle:
            return hfsPath(urlPath: urlPath, encoding: encoding)
        default:
            return nil
        }
    }
}

/// Call this function when `pathBuffer` has already been allocated with enough
/// space for a trailing slash and we can modify the buffer directly instead of
/// making a separate allocation.
///
/// - Note: `pathBuffer` must be larger than `pathLength`, which
///   should point to the end of the FSR (first null byte).
private func parseMutableFileSystemRepresentation(_ pathBuffer: UnsafeMutableBufferPointer<UInt8>, pathLength: Int, flags: inout __CFURLFlags, isDirectory: Bool) -> String {
    // Note: pathLength can technically be 0 for FSRs like "\0".
    assert(pathBuffer.count > 0)
    assert(pathLength < pathBuffer.count) // Need room for a trailing slash

    var pathLength = pathLength
    if isDirectory {
        flags.insert(.hasDirectoryPath)
        // Append a trailing "/" if one doesn't exist already
        if pathBuffer[pathLength - 1] != UInt8(ascii: "/") {
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

    let fileIDPrefixSize = 10 // "/.file/id="
    let isFileReferenceURL = (
        pathLength >= fileIDPrefixSize &&
        strncmp(pathBuffer.baseAddress!, "/.file/id=", fileIDPrefixSize) == 0
    )

    // Note: don't insert .hasOldNetLocation, which only considers a non-empty authority
    var isAbsolute = true
    if isFileReferenceURL {
        flags.insert([.hasScheme, .hasHost, .isFileURL, .isFileReferenceURL])
    } else if pathBuffer[0] == UInt8(ascii: "/") {
        flags.insert([.hasScheme, .hasHost, .isFileURL])
    } else {
        // We don't know if this is a file URL without checking the base
        isAbsolute = false
    }

    // Return the full (maybe percent-encoded) URL string
    var maxEncodedSize = 3 * pathLength
    let filePrefixSize = 7 // "file://"
    if isAbsolute {
        maxEncodedSize += filePrefixSize
    }
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxEncodedSize) { encodedBuffer in
        var pathStart = 0
        if isAbsolute {
            memcpy(encodedBuffer.baseAddress!, "file://", filePrefixSize)
            pathStart = filePrefixSize
        }
        let bytesWritten = URLEncoder.percentEncodeUnchecked(
            input: UnsafeBufferPointer(rebasing: pathBuffer[..<pathLength]),
            output: UnsafeMutableBufferPointer(rebasing: encodedBuffer[pathStart...]),
            // Encode ";" for compatibility
            component: .pathNoSemicolon,
            skipAlreadyEncoded: false
        )
        if bytesWritten != pathLength {
            // The path was percent-encoded
            flags.insert(.hasEncodedPath)
        }
        return String(decoding: encodedBuffer[..<(pathStart + bytesWritten)], as: UTF8.self)
    }
}

private func parseFileSystemRepresentation(buffer: UnsafeBufferPointer<UInt8>, flags: inout __CFURLFlags, isDirectory: Bool) -> String? {
    // Check for null bytes.
    var pathLength = buffer.count
    if let nullIndex = buffer.firstIndex(of: 0) {
        // Embedded null bytes aren't allowed, but it's okay if all the remaining bytes are null.
        guard buffer[(nullIndex + 1)...].allSatisfy({ $0 == 0 }) else {
            return nil
        }
        pathLength = nullIndex
    }

    // Allocate an extra byte in case we need to append a directory slash.
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: pathLength + 1) { pathBuffer in
        _ = pathBuffer.initialize(fromContentsOf: buffer[..<pathLength])
        return parseMutableFileSystemRepresentation(pathBuffer, pathLength: pathLength, flags: &flags, isDirectory: isDirectory)
    }
}

private func parsePOSIX(_ path: CFString, flags: inout __CFURLFlags, isDirectory: Bool) -> String? {
    // Convert path to its decomposed file system representation
    let length = CFStringGetLength(path)
    // Checking for ASCII and avoiding bridging gets us from 2.2x slower to
    // 1.2x faster for larger paths, and over 2x faster for shorter paths.
    if let ptr = CFStringGetCStringPtr(path, CFStringBuiltInEncodings.ASCII.rawValue) {
        return ptr.withMemoryRebound(to: UInt8.self, capacity: length) {
            // This checks for null bytes.
            return parseFileSystemRepresentation(
                buffer: UnsafeBufferPointer(start: $0, count: length),
                flags: &flags,
                isDirectory: isDirectory
            )
        }
    }
    let maxFSRSize = CFStringGetMaximumSizeOfFileSystemRepresentation(path) + (isDirectory ? 1 : 0)
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxFSRSize) { pathBuffer in
        guard let pathLength = (path as String)._decomposed(.hfsPlus, into: pathBuffer), pathLength > 0 else {
            return nil
        }
        // _decomposed(_:into:) already checks for embedded null bytes
        return parseMutableFileSystemRepresentation(pathBuffer, pathLength: pathLength, flags: &flags, isDirectory: isDirectory)
    }
}

private func parseWindows(_ path: String, flags: inout __CFURLFlags, isDirectory: Bool) -> String? {
    var path = path.replacing(._backslash, with: ._slash)
    // Standardizes an absolute path like "C:/" to "/C:/"
    _ = URL.isAbsolute(standardizing: &path, pathStyle: .windows)
    return path.withUTF8 { pathBuffer in
        guard !pathBuffer.isEmpty else {
            return nil
        }
        return parseFileSystemRepresentation(buffer: pathBuffer, flags: &flags, isDirectory: isDirectory)
    }
}

private func parseHFS(_ path: String, flags: inout __CFURLFlags, isDirectory: Bool) -> String? {
    var path = posixLikePath(fromHFSPath: path)
    return path.withUTF8 { pathBuffer in
        guard !pathBuffer.isEmpty else {
            return nil as String?
        }
        return parseFileSystemRepresentation(buffer: pathBuffer, flags: &flags, isDirectory: isDirectory)
    }
}

// Note this does not percent-encode the path
private func posixLikePath(fromHFSPath path: String) -> String {
    // Check if the path contains "::" which needs resolution
    var path = path
    if path.utf8.contains([._colon, ._colon]) {
        var bytes = Array(path.utf8)
        var readIndex = 0
        var writeIndex = 0
        var firstColonIndex: Int?

        while readIndex < bytes.count {
            if bytes[readIndex] == ._colon {
                let isDoubleColon = (readIndex + 1 < bytes.count) && (bytes[readIndex + 1] == ._colon)
                if isDoubleColon {
                    if writeIndex > 0, let firstColonIndex {
                        writeIndex -= 1
                        while writeIndex > 0 && writeIndex >= firstColonIndex && bytes[writeIndex] != ._colon {
                            writeIndex -= 1
                        }
                    }
                    readIndex += 1
                }

                if firstColonIndex == nil {
                    firstColonIndex = writeIndex
                }
            }

            bytes[writeIndex] = bytes[readIndex]
            writeIndex += 1
            readIndex += 1
        }

        path = String(decoding: bytes[0..<writeIndex], as: UTF8.self)
    }

    func components(fromHFSPath path: String) -> [String] {
        var components = path.split(separator: ":").map(String.init)
        if path.utf8.first != ._colon {
            if components.first?.utf8.count == 1, components.first?.utf8.first == ._slash {
                // "/" is the "magic" path for a UFS root directory
                components[0] = ""
            } else {
                // See if we can get a mount point
                #if !NO_FILESYSTEM && os(macOS)
                if let mountPath = __CFURLCopyMountPathForVolumeName(components.first! as CFString) as String? {
                    components.removeFirst()
                    components.insert(contentsOf: mountPath.split(separator: "/").map(String.init), at: 0)
                }
                #endif
                components.insert("", at: 0)
            }
        } else {
            components.removeFirst()
        }
        return components.map { $0.replacing(._slash, with: ._colon) }
    }

    let components = components(fromHFSPath: path)
    if components.count == 1 && components.first?.isEmpty == true {
        return "/"
    }
    return components.joined(separator: "/")
}

private func posixPath(urlPath: String, encoding: String.Encoding, isFileURL: Bool) -> String? {
    return URLEncoder.percentDecode(
        string: urlPath,
        encoding: encoding,
        excludingASCII: isFileURL ? .posixPath : .none
    )?._droppingTrailingSlash
}

private func windowsPath(urlPath: String, encoding: String.Encoding) -> String? {
    var iter = urlPath.utf8.makeIterator()
    guard iter.next() == ._slash else {
        return URLEncoder.percentDecode(
            string: urlPath,
            encoding: .utf8,
            excludingASCII: .windowsPath
        )?._droppingTrailingSlash.replacing(._slash, with: ._backslash)
    }
    if urlPath.utf8.count == 1 {
        // Previous behavior for "/", should remove eventually
        return ""
    }
    // "C:\" is standardized to "/C:/" on initialization.
    if let driveLetter = iter.next(), driveLetter.isAlpha,
       iter.next() == ._colon,
       iter.next() == ._slash {
        // Strip trailing slashes from the path, which preserves a root "/".
        var path = String(Substring(urlPath.utf8.dropFirst(3)))._droppingTrailingSlash
        path = URLEncoder.percentDecode(
            string: path,
            encoding: encoding,
            excludingASCII: .windowsPath
        )?.replacing(._slash, with: ._backslash) ?? path
        // Don't include a leading slash before the drive letter
        return "\(Unicode.Scalar(driveLetter)):\(path)"
    }
    return URLEncoder.percentDecode(
        string: urlPath,
        encoding: encoding,
        excludingASCII: .windowsPath
    )?._droppingTrailingSlash.replacing(._slash, with: ._backslash)
}

private func hfsPath(urlPath: String, encoding: String.Encoding) -> String? {
    #if NO_FILESYSTEM || !os(macOS)
    return nil // CFURLCopyFileSystemPath behavior
    #else
    guard !urlPath.isEmpty else {
        return ""
    }
    if urlPath.utf8.first == ._slash {
        let posixPath = posixPath(urlPath: urlPath, encoding: encoding, isFileURL: true)
        return posixPath?.withFileSystemRepresentation { fsRep in
            guard let fsRep else {
                return nil
            }
            return __CFURLCreateHFSPathForFileSystemRepresentation(fsRep) as String?
        }
    } else {
        var components = urlPath._compressingSlashes()._droppingTrailingSlashes.split(separator: "/")
        components.insert("", at: 0)
        return components.map {
            let decoded = URLEncoder.percentDecode(string: String($0), encoding: encoding) ?? String($0)
            return decoded.replacing(._colon, with: ._slash)
        }.joined(separator: ":")
    }
    #endif // NO_FILESYSTEM
}

#if !NO_FILESYSTEM
private func filePath(for fileReferencePath: String, resolveFlags: UInt32 = 0) -> String? {
    var fileReferencePath = fileReferencePath
    return fileReferencePath.withUTF8 { buffer -> String? in
        guard buffer.starts(with: URL.fileIDPrefix) else {
            return nil
        }
        let volumeIDStart = URL.fileIDPrefix.count
        guard let volumeIDEnd = buffer[volumeIDStart...].firstIndex(of: ._dot) else {
            return nil
        }
        let volumeIDStr = String(decoding: buffer[volumeIDStart..<volumeIDEnd], as: UTF8.self)
        guard let volumeID = Int64(volumeIDStr) else {
            return nil
        }
        let fileIDStart = volumeIDEnd + 1
        let fileIDEnd = buffer[fileIDStart...].firstIndex(of: ._slash) ?? buffer.endIndex
        let fileIDStr = String(decoding: buffer[fileIDStart..<fileIDEnd], as: UTF8.self)
        let fileID = Int64(fileIDStr) ?? Int64(0)
        guard let path = __CFURLCreatePathForFileID(volumeID, fileID) as String?, !path.isEmpty else {
            return nil
        }
        let urlPath = URLEncoder.percentEncode(string: path, component: .path, skipAlreadyEncoded: false)
        let fullPath = urlPath + String(decoding: buffer[fileIDEnd...], as: UTF8.self)
        if resolveFlags != 0 {
            return fullPath._insertingPathResolveFlags(resolveFlags)
        }
        return fullPath
    }
}
#endif

#endif
