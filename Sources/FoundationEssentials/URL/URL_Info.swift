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
internal typealias _URLImplType = __CFURLImplType
#else
internal enum _URLImplType: UInt32 {
    case file = 2
}

internal struct _URLFlags: OptionSet {
    let rawValue: UInt32

    static var implTypeMask:            Self { Self(rawValue: 0b11) }

    static var hasScheme:               Self { Self(rawValue: 1 << 2) }
    static var hasHost:                 Self { Self(rawValue: 1 << 3) }
    static var hasPort:                 Self { Self(rawValue: 1 << 4) }
    static var hasOldPath:              Self { Self(rawValue: 1 << 5) }
    static var hasQuery:                Self { Self(rawValue: 1 << 6) }
    static var hasFragment:             Self { Self(rawValue: 1 << 7) }

    static var hasUser:                 Self { Self(rawValue: 1 << 8) }
    static var hasPassword:             Self { Self(rawValue: 1 << 9) }

    // Frequently used flags for compatibility
    static var isDecomposable:          Self { Self(rawValue: 1 << 10) }
    static var hasOldNetLocation:       Self { Self(rawValue: 1 << 11) }

    static var isFileURL:               Self { Self(rawValue: 1 << 12) }
    static var isFileReferenceURL:      Self { Self(rawValue: 1 << 13) }
    static var hasDirectoryPath:        Self { Self(rawValue: 1 << 14) }
    static var hasEncodedPath:          Self { Self(rawValue: 1 << 15) }

    static var hasNonUTF8Encoding:      Self { Self(rawValue: 1 << 16) }
    static var isIPLiteral:             Self { Self(rawValue: 1 << 17) }
    static var shouldEncodeUser:        Self { Self(rawValue: 1 << 18) }
    static var shouldEncodePassword:    Self { Self(rawValue: 1 << 19) }
    static var shouldEncodeHost:        Self { Self(rawValue: 1 << 20) }
    static var shouldEncodePath:        Self { Self(rawValue: 1 << 21) }
    static var shouldEncodeQuery:       Self { Self(rawValue: 1 << 22) }
    static var shouldEncodeFragment:    Self { Self(rawValue: 1 << 23) }

    // WHATWG URL special schemes (ftp, file, http, https, ws, wss)
    static var hasSpecialScheme:         Self { Self(rawValue: 1 << 24) }

    // Flags that are guaranteed to be set in a canonical file URL
    static var fileImplFlags: Self { [.init(type: .file), .hasOldPath, .isDecomposable] }
}
#endif

extension _URLFlags {
    init(type: _URLImplType) {
        self.init(rawValue: type.rawValue)
    }

    // Swift URL only stores the fully-encoded URL string, so the presence of
    // these "should" encode flags imply that those components were encoded.
    static var didEncodeUser:       Self { .shouldEncodeUser }
    static var didEncodePassword:   Self { .shouldEncodePassword }
    static var didEncodeHost:       Self { .shouldEncodeHost }
    static var didEncodePath:       Self { .shouldEncodePath }
    static var didEncodeQuery:      Self { .shouldEncodeQuery }
    static var didEncodeFragment:   Self { .shouldEncodeFragment }
}

internal struct _URLInfo: _URLParseable, _URLHeader {
    static var maxStringLength: Int { Int.max }
    var string: String
    var flags: _URLFlags = []

    // Ranges are valid for the string's UTF8 bytes
    var schemeRange:    Range<Int> = 0..<0
    var hostRange:      Range<Int> = 0..<0
    var portRange:      Range<Int> = 0..<0
    var pathRange:      Range<Int> = 0..<0
    var queryRange:     Range<Int> = 0..<0
    var fragmentRange:  Range<Int> = 0..<0
    var userRange:      Range<Int> = 0..<0
    var passwordRange:  Range<Int> = 0..<0

    var hasScheme: Bool     { flags.contains(.hasScheme) }
    var hasUser: Bool       { flags.contains(.hasUser) }
    var hasPassword: Bool   { flags.contains(.hasPassword) }
    var hasHost: Bool       { flags.contains(.hasHost) }
    var hasPort: Bool       { flags.contains(.hasPort) }
    var hasPath: Bool       { true } // Path always exists
    var hasQuery: Bool      { flags.contains(.hasQuery) }
    var hasFragment: Bool   { flags.contains(.hasFragment) }

    mutating func setOriginalString(_ string: String) {
        self.string = string
    }

    mutating func setEncodedString(_ string: String) {
        // This function is used by CFURL to set an additional encoded string.
        // Since URL only ever stores one string (which may be encoded), this
        // function should never be called.
        fatalError("Unreachable")
    }

    func withSpan<R>(_ block: (borrowing Span<UInt8>) -> R) -> R {
        var s = string
        return s.withUTF8 { block($0.span) }
    }

    @inline(__always)
    private func substring(_ range: Range<Int>) -> Substring {
        let start = string.utf8.index(string.startIndex, offsetBy: range.startIndex)
        let end = string.utf8.index(string.startIndex, offsetBy: range.endIndex)
        return string[start..<end]
    }

    var scheme: Substring? {
        flags.contains(.hasScheme) ? substring(schemeRange) : nil
    }

    var user: Substring? {
        flags.contains(.hasUser) ? substring(userRange) : nil
    }

    var password: Substring? {
        flags.contains(.hasPassword) ? substring(passwordRange) : nil
    }

    var host: Substring? {
        flags.contains(.hasHost) ? substring(hostRange) : nil
    }

    var portString: Substring? {
        flags.contains(.hasPort) ? substring(portRange) : nil
    }

    var port: Int? {
        portString.flatMap { Int($0) }
    }

    var path: Substring {
        substring(pathRange)
    }

    var query: Substring? {
        flags.contains(.hasQuery) ? substring(queryRange) : nil
    }

    var fragment: Substring? {
        flags.contains(.hasFragment) ? substring(fragmentRange) : nil
    }

    static func parse(
        string: String,
        encodingInvalidCharacters: Bool
    ) -> _URLInfo? {
        var info = _URLInfo(string: string)
        var flags: _URLFlags = []
        var s = string
        return s.withUTF8 {
            guard URL.parse(
                UTF8.self,
                span: $0.span,
                flags: &flags,
                into: &info,
                allowEncoding: encodingInvalidCharacters,
                useModernParsing: true
            ) else {
                return nil
            }
            info.flags = flags
            return info
        }
    }
}

// MARK: - File path parsing

extension _URLInfo {
    @inline(__always)
    private static func filePathInfo(string: String, flags: _URLFlags) -> _URLInfo {
        // String is the fully-encoded URL string such as "file:///path"
        let schemeRange: Range<Int>
        let hostRange: Range<Int>
        let pathRange: Range<Int>
        if flags.contains(.hasScheme) {
            schemeRange = 0..<4 // "file"
            hostRange = 7..<7 // Empty host in "file:///path"
            pathRange = 7..<string.utf8.count
        } else {
            // Relative path only
            schemeRange = 0..<0
            hostRange = 0..<0
            pathRange = 0..<string.utf8.count
        }
        return _URLInfo(
            string: string,
            flags: flags,
            schemeRange: schemeRange,
            hostRange: hostRange,
            portRange: 0..<0,
            pathRange: pathRange,
            queryRange: 0..<0,
            fragmentRange: 0..<0,
            userRange: 0..<0,
            passwordRange: 0..<0
        )
    }

    @inline(__always)
    private static func resolveBaseURL(_ base: URL?, updating flags: inout _URLFlags) -> URL? {
        if flags.contains(.hasScheme) {
            // Absolute file path, drop the base URL
            return nil
        }
        // Relative file path
        if let base = base?.absoluteURL {
            if base.isFileURL {
                flags.insert(.isFileURL)
            }
            return base
        }
        #if !NO_FILESYSTEM
        if let cwd = URL.currentDirectoryOrNil() {
            flags.insert(.isFileURL)
            return cwd
        }
        #endif
        return nil
    }

    static func parse(
        filePath: String,
        pathStyle: URL.PathStyle,
        isDirectory: Bool,
        relativeTo base: URL?
    ) -> (info: _URLInfo, baseURL: URL?) {
        var flags = _URLFlags.fileImplFlags
        guard !filePath.isEmpty else {
            flags.insert(.hasDirectoryPath)
            let base = resolveBaseURL(base, updating: &flags)
            return (filePathInfo(string: "./", flags: flags), base)
        }

        let urlString = switch pathStyle {
        case .posix: URL.parsePOSIXPath(filePath, flags: &flags, isDirectory: isDirectory)
        case .windows: URL.parseWindowsPath(filePath, flags: &flags, isDirectory: isDirectory)
        }

        let base = resolveBaseURL(base, updating: &flags)
        return (filePathInfo(string: urlString, flags: flags), base)
    }

    static func parse(
        fileSystemRepresentation: UnsafePointer<Int8>,
        length: Int,
        isDirectory: Bool,
        relativeTo base: URL?
    ) -> (info: _URLInfo, baseURL: URL?) {
        var flags = _URLFlags.fileImplFlags
        guard length > 0 else {
            flags.insert(.hasDirectoryPath)
            let base = resolveBaseURL(base, updating: &flags)
            return (filePathInfo(string: "./", flags: flags), base)
        }

        let urlString = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length + 1) { buffer in
            fileSystemRepresentation.withMemoryRebound(to: UInt8.self, capacity: length) {
                buffer.baseAddress!.initialize(from: $0, count: length)
            }
            let finalLength = URL.finalPathLength(
                updating: buffer,
                currentLength: length,
                flags: &flags,
                isDirectory: isDirectory
            )
            let path = buffer.span.extracting(first: finalLength)
            return URL.parseFinalFileSystemRepresentation(path: path, flags: &flags, encodeSemicolons: false)
        }

        let base = resolveBaseURL(base, updating: &flags)
        return (filePathInfo(string: urlString, flags: flags), base)
    }
}


// MARK: - Updating _URLInfo

extension _URLInfo {
    func inserting(flags: _URLFlags) -> _URLInfo {
        var result = self
        result.flags.formUnion(flags)
        return result
    }

    enum PathEncodingState {
        case notEncoded
        case encoded
        case unknown
    }

    func replacing(
        path: borrowing Span<UInt8>,
        encodingState: PathEncodingState = .unknown
    ) -> _URLInfo {
        let isDirectory = path.withUnsafeBufferPointer {
            URL.hasDirectoryPath($0, pathEnd: $0.count, pathLength: $0.count)
        }
        return replacing(path: path, isDirectory: isDirectory, encodingState: encodingState)
    }

    func replacing(
        path newPath: borrowing Span<UInt8>,
        isDirectory: Bool,
        encodingState: PathEncodingState
    ) -> _URLInfo {
        let pathDelta = newPath.count - pathRange.count
        let newString = withSpan { stringSpan in
            let newLength = stringSpan.count + pathDelta
            return String(unsafeUninitializedCapacity: newLength) { buffer in
                var writeIndex = buffer.initialize(
                    fromSpan: stringSpan.extracting(..<pathRange.startIndex)
                )
                writeIndex = buffer[writeIndex...].initialize(
                    fromSpan: newPath
                )
                writeIndex = buffer[writeIndex...].initialize(
                    fromSpan: stringSpan.extracting(pathRange.endIndex...)
                )
                return writeIndex
            }
        }

        // Update flags for the new path
        var flags = flags
        if (!newPath.isEmpty && flags.contains(.isDecomposable)) ||
            (newPath.isEmpty && flags.contains(.hasOldNetLocation)) {
            flags.insert(.hasOldPath)
        } else {
            flags.remove(.hasOldPath)
        }

        assert(isDirectory == newPath.withUnsafeBufferPointer {
            URL.hasDirectoryPath($0, pathEnd: $0.count, pathLength: $0.count)
        })
        if isDirectory {
            flags.insert(.hasDirectoryPath)
        } else {
            flags.remove(.hasDirectoryPath)
        }

        let hasEncodedPath: Bool
        switch encodingState {
        case .notEncoded:
            assert(!newPath.contains(UInt8(ascii: "%")))
            hasEncodedPath = false
        case .encoded:
            assert(newPath.contains(UInt8(ascii: "%")))
            hasEncodedPath = true
        case .unknown:
            hasEncodedPath = newPath.contains(UInt8(ascii: "%"))
        }

        if hasEncodedPath {
            flags.insert(.hasEncodedPath)
        } else {
            flags.remove(.hasEncodedPath)
        }

        // Remove all .didEncode flags since we're treating this
        // as a new, validly percent-encoded (UTF8) URL string.
        flags.remove([
            .hasNonUTF8Encoding,
            .didEncodeUser, .didEncodePassword, .didEncodeHost,
            .didEncodePath, .didEncodeQuery, .didEncodeFragment
        ])

        var result = self
        result.string = newString
        result.flags = flags
        result.pathRange = pathRange.startIndex..<(pathRange.startIndex + newPath.count)

        // Shift the query and fragment ranges to account for the new path
        if flags.contains(.hasQuery) {
            result.queryRange = queryRange.shifted(by: pathDelta)
        }
        if flags.contains(.hasFragment) {
            result.fragmentRange = fragmentRange.shifted(by: pathDelta)
        }
        return result
    }
}

private extension Range<Int> {
    func shifted(by delta: Int) -> Range<Int> {
        return (lowerBound + delta)..<(upperBound + delta)
    }
}

// MARK: - Original string

extension _URLInfo {
    var originalString: String {
        if flags.isDisjoint(with: [
            .didEncodeUser, .didEncodePassword, .didEncodeHost,
            .didEncodePath, .didEncodeQuery, .didEncodeFragment
        ]) {
            return string
        }
        return withSpan { stringSpan in
            String(unsafeUninitializedCapacity: stringSpan.count) { buffer in
                var writeIndex = 0

                @inline(__always)
                func decode(range: Range<Int>) -> Int? {
                    URLEncoder.percentDecodeUnchecked(
                        input: stringSpan.extracting(range),
                        output: .init(rebasing: buffer[writeIndex...])
                    )
                }

                if hasScheme {
                    writeIndex = buffer.initialize(
                        fromSpan: stringSpan.extracting(schemeRange)
                    )
                    buffer[writeIndex] = UInt8(ascii: ":")
                    writeIndex += 1
                }
                if hasHost {
                    buffer[writeIndex] = UInt8(ascii: "/")
                    buffer[writeIndex + 1] = UInt8(ascii: "/")
                    writeIndex += 2
                }
                if hasUser {
                    if flags.contains(.didEncodeUser), let written = decode(range: userRange) {
                        writeIndex += written
                    } else {
                        writeIndex = buffer[writeIndex...].initialize(
                            fromSpan: stringSpan.extracting(userRange)
                        )
                    }
                    if hasPassword {
                        buffer[writeIndex] = UInt8(ascii: ":")
                        writeIndex += 1
                        if flags.contains(.didEncodePassword), let written = decode(range: passwordRange) {
                            writeIndex += written
                        } else {
                            writeIndex = buffer[writeIndex...].initialize(
                                fromSpan: stringSpan.extracting(passwordRange)
                            )
                        }
                    }
                    buffer[writeIndex] = UInt8(ascii: "@")
                    writeIndex += 1
                }
                if hasHost {
                    if !flags.contains(.didEncodeHost) {
                        writeIndex = buffer[writeIndex...].initialize(
                            fromSpan: stringSpan.extracting(hostRange)
                        )
                    } else {
                        let shouldPercentDecode = (
                            !flags.contains(.hasSpecialScheme) || flags.contains(.isIPLiteral) || _uidnaHook() == nil
                        )
                        if shouldPercentDecode, let written = decode(range: hostRange) {
                            writeIndex += written
                        } else {
                            writeIndex = buffer[writeIndex...].initialize(
                                fromSpan: stringSpan.extracting(hostRange)
                            )
                        }
                    }
                }
                if hasPort {
                    buffer[writeIndex] = UInt8(ascii: ":")
                    writeIndex += 1
                    writeIndex = buffer[writeIndex...].initialize(
                        fromSpan: stringSpan.extracting(portRange)
                    )
                }
                if flags.contains(.didEncodePath), let written = decode(range: pathRange) {
                    writeIndex += written
                } else {
                    writeIndex = buffer[writeIndex...].initialize(
                        fromSpan: stringSpan.extracting(pathRange)
                    )
                }
                if hasQuery {
                    buffer[writeIndex] = UInt8(ascii: "?")
                    writeIndex += 1
                    if flags.contains(.didEncodeQuery), let written = decode(range: queryRange) {
                        writeIndex += written
                    } else {
                        writeIndex = buffer[writeIndex...].initialize(
                            fromSpan: stringSpan.extracting(queryRange)
                        )
                    }
                }
                if hasFragment {
                    buffer[writeIndex] = UInt8(ascii: "#")
                    writeIndex += 1
                    if flags.contains(.didEncodeFragment), let written = decode(range: fragmentRange) {
                        writeIndex += written
                    } else {
                        writeIndex = buffer[writeIndex...].initialize(
                            fromSpan: stringSpan.extracting(fragmentRange)
                        )
                    }
                }
                return writeIndex
            }
        }
    }
}
