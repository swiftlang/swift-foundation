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

#if canImport(Darwin)
internal import os
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import WinSDK
#elseif os(WASI)
import WASILibc
#endif

internal import _FoundationCShims

extension StringProtocol {
    fileprivate func _convertingSlashesIfNeeded() -> String {
        #if os(Windows)
        // The string functions below all assume that the path separator is a forward slash
        // Standardize the path to use forward slashes before processing for consistency
        return self.replacing(._backslash, with: ._slash)
        #else
        if let str = _specializingCast(self, to: String.self) {
            return str
        } else {
            return String(self)
        }
        #endif
    }
}

extension String {

    // MARK: - Non-filesystem String Extensions

    internal var pathComponents: [String] {
        _convertingSlashesIfNeeded()._pathComponents
    }

    private var _pathComponents: [String] {
        guard !isEmpty else {
            return []
        }
        var result = [String]()

        var start = startIndex
        if utf8.first == ._slash {
            result.append("/")
            start = utf8.firstIndex { $0 != ._slash } ?? endIndex
        }
        var end = start
        while end != endIndex {
            end = utf8[end...].firstIndex(of: ._slash) ?? endIndex
            if start != end {
                result.append(String(self[start..<end]))
            }
            start = utf8[end...].firstIndex { $0 != ._slash } ?? endIndex
            end = start
        }
        if utf8.count > 1 && utf8.last == ._slash {
            result.append("/")
        }
        return result
    }

    internal func deletingLastPathComponent() -> String {
        _convertingSlashesIfNeeded()._deletingLastPathComponent()
    }
    
    private func _deletingLastPathComponent() -> String {
        guard let lastSlash = utf8.lastIndex(of: ._slash) else {
            // No slash, entire string is deleted
            return ""
        }

        // Skip past consecutive slashes, if any (e.g. find "y" in "/my//path" or "h" in "/path//")
        guard let lastNonSlash = self[..<lastSlash].utf8.lastIndex(where: { $0 != ._slash }) else {
            // String consists entirely of slashes, return a single slash
            return "/"
        }

        let hasTrailingSlash = (lastSlash == utf8.index(before: endIndex))
        guard hasTrailingSlash else {
            // No trailing slash, return up to (including) the last non-slash character
            return String(self[...lastNonSlash])
        }

        // We have a trailing slash, find the slash before the last component
        guard let previousSlash = self[..<lastNonSlash].utf8.lastIndex(of: ._slash) else {
            // No prior slash, deleting the last component removes the entire string (e.g. "path/")
            return ""
        }

        // Again, skip past consecutive slashes, if any (e.g. find "y" in "/my//path/")
        guard let previousNonSlash = self[..<previousSlash].utf8.lastIndex(where: { $0 != ._slash }) else {
            // String is an absolute path with a single component (e.g. "/path/" or "//path/")
            return "/"
        }

        return String(self[...previousNonSlash])
    }
        
    internal func appendingPathComponent(_ component: String) -> String {
        _convertingSlashesIfNeeded()._appendingPathComponent(component)
    }
    
    private func _appendingPathComponent(_ component: String) -> String {
        guard !isEmpty else {
            return component._standardizingSlashes
        }

        if utf8.elementsEqual([._backslash, ._backslash]) {
            return self + component._standardizingSlashes
        }

        return (self + "/" + component)._standardizingSlashes
    }

    internal var lastPathComponent: String {
        _convertingSlashesIfNeeded()._lastPathComponent
    }
    
    private var _lastPathComponent: String {
        guard utf8.count > 1 else {
            return self
        }

        guard let lastSlash = utf8.lastIndex(of: ._slash) else {
            // No slash, just return self
            return self
        }

        guard lastSlash == utf8.index(before: endIndex) else {
            // Not a trailing slash, return the component after it
            return String(self[utf8.index(after: lastSlash)...])
        }

        // We have a trailing slash. Ignore it and all slashes that directly precede it
        guard let lastNonSlash = self[..<lastSlash].utf8.lastIndex(where: { $0 != ._slash }) else {
            // String is all slashes, return a bare slash
            return "/"
        }

        guard let previousSlash = self[..<lastNonSlash].utf8.lastIndex(of: ._slash) else {
            return String(self[...lastNonSlash])
        }

        return String(self[utf8.index(after: previousSlash)...lastNonSlash])
    }

    // Internal for testing purposes
    internal static let invalidExtensionScalars = Set<Unicode.Scalar>([
        " ",
        "/",
        "\u{061c}", // ARABIC LETTER MARK
        "\u{200e}", // LEFT-TO-RIGHT MARK
        "\u{200f}", // RIGHT-TO-LEFT MARK
        "\u{202a}", // LEFT-TO-RIGHT EMBEDDING
        "\u{202b}", // RIGHT-TO-LEFT EMBEDDING
        "\u{202c}", // POP DIRECTIONAL FORMATTING
        "\u{202d}", // LEFT-TO-RIGHT OVERRIDE
        "\u{202e}", // RIGHT-TO-LEFT OVERRIDE
        "\u{2066}", // LEFT-TO-RIGHT ISOLATE
        "\u{2067}", // RIGHT-TO-LEFT ISOLATE
        "\u{2068}", // FIRST STRONG ISOLATE
        "\u{2069}", // POP DIRECTIONAL ISOLATE
    ])

    internal func deletingPathExtension() -> String {
        guard !pathExtension.isEmpty else {
            return self
        }
        guard let lastDot = utf8.lastIndex(of: ._dot) else {
            return self
        }
        var result = String(self[..<lastDot])
        if utf8.last == ._slash {
            result += "/"
        }
        return result
    }

    private func validatePathExtension(_ pathExtension: String) -> Bool {
        guard pathExtension.utf8.last != ._dot else {
            return false
        }
        if let lastDot = pathExtension.utf8.lastIndex(of: ._dot) {
            let beforeDot = pathExtension[..<lastDot]._convertingSlashesIfNeeded().unicodeScalars
            let afterDot = pathExtension[pathExtension.index(after: lastDot)...]._convertingSlashesIfNeeded().unicodeScalars
            return beforeDot.allSatisfy { $0 != "/" } && afterDot.allSatisfy { !String.invalidExtensionScalars.contains($0) }
        } else {
            return pathExtension._convertingSlashesIfNeeded().unicodeScalars.allSatisfy { !String.invalidExtensionScalars.contains($0) }
        }
    }

    internal func appendingPathExtension(_ pathExtension: String) -> String {
        guard validatePathExtension(pathExtension) else {
            return self
        }
        var result = self._droppingTrailingSlashes
        guard result != "/" else {
            // Path was all slashes
            return self + ".\(pathExtension)"
        }
        result += ".\(pathExtension)"
        if utf8.last == ._slash {
            result += "/"
        }
        return result
    }

    internal var pathExtension: String {
        let lastComponent = lastPathComponent.utf8
        guard lastComponent.last != ._dot,
              !lastComponent.starts(with: [._dot, ._dot]),
              let lastDot = lastComponent.lastIndex(of: ._dot),
              lastDot != lastComponent.startIndex else {
            return ""
        }
        let result = String(lastPathComponent[lastComponent.index(after: lastDot)...])
        guard validatePathExtension(result) else {
            return ""
        }
        return result
    }

    internal func merging(relativePath: String) -> String {
        _convertingSlashesIfNeeded()._merging(relativePath: relativePath)
    }
    
    private func _merging(relativePath: String) -> String {
        guard relativePath.utf8.first != ._slash else {
            return relativePath
        }
        guard let basePathEnd = self.utf8.lastIndex(of: ._slash) else {
            return relativePath
        }
        return self[...basePathEnd] + relativePath
    }

    internal var removingDotSegments: String {
        _convertingSlashesIfNeeded()._removingDotSegments
    }
    
    private var _removingDotSegments: String {
        guard !isEmpty else {
            return ""
        }

        enum RemovingDotState {
            case initial
            case dot
            case dotDot
            case slash
            case slashDot
            case slashDotDot
            case appendUntilSlash
        }

        return String(unsafeUninitializedCapacity: utf8.count) { buffer in

            // State machine for remove_dot_segments() from RFC 3986
            //
            // First, remove all "./" and "../" prefixes by moving through
            // the .initial, .dot, and .dotDot states (without appending).
            //
            // Then, move through the remaining states/components, first
            // checking if the component is special ("/./" or "/../") so
            // that we only append when necessary.

            var state = RemovingDotState.initial
            var i = 0
            for v in utf8 {
                switch state {
                case .initial:
                    if v == ._dot {
                        state = .dot
                    } else if v == ._slash {
                        state = .slash
                    } else {
                        buffer[i] = v
                        i += 1
                        state = .appendUntilSlash
                    }
                case .dot:
                    if v == ._dot {
                        state = .dotDot
                    } else if v == ._slash {
                        state = .initial
                    } else {
                        i = buffer[i...i+1].initialize(fromContentsOf: [._dot, v])
                        state = .appendUntilSlash
                    }
                case .dotDot:
                    if v == ._slash {
                        state = .initial
                    } else {
                        i = buffer[i...i+2].initialize(fromContentsOf: [._dot, ._dot, v])
                        state = .appendUntilSlash
                    }
                case .slash:
                    if v == ._dot {
                        state = .slashDot
                    } else if v == ._slash {
                        buffer[i] = ._slash
                        i += 1
                    } else {
                        i = buffer[i...i+1].initialize(fromContentsOf: [._slash, v])
                        state = .appendUntilSlash
                    }
                case .slashDot:
                    if v == ._dot {
                        state = .slashDotDot
                    } else if v == ._slash {
                        state = .slash
                    } else {
                        i = buffer[i...i+2].initialize(fromContentsOf: [._slash, ._dot, v])
                        state = .appendUntilSlash
                    }
                case .slashDotDot:
                    if v == ._slash {
                        // Cheaply remove the previous component by moving i to its start
                        i = buffer[..<i].lastIndex(of: ._slash) ?? 0
                        state = .slash
                    } else {
                        i = buffer[i...i+3].initialize(fromContentsOf: [._slash, ._dot, ._dot, v])
                        state = .appendUntilSlash
                    }
                case .appendUntilSlash:
                    if v == ._slash {
                        state = .slash
                    } else {
                        buffer[i] = v
                        i += 1
                    }
                }
            }

            switch state {
            case .slash: fallthrough
            case .slashDot:
                buffer[i] = ._slash
                i += 1
            case .slashDotDot:
                // Note: "/.." is not yet appended to the buffer
                i = buffer[..<i].lastIndex(of: ._slash) ?? 0
                buffer[i] = ._slash
                i += 1
            default:
                break
            }

            return i
        }
    }

    /// Replaces any number of sequential `/`
    /// characters with a single `/`
    /// NOTE: Internal so it's testable
    /// - Returns: The replaced String
    internal func _compressingSlashes() -> String {
        guard utf8.count > 1 else {
            return self
        }

        enum SlashState {
            case initial
            case slash
        }

        return String(unsafeUninitializedCapacity: utf8.count) { buffer in
            var state = SlashState.initial
            var i = 0
            for v in utf8 {
                switch state {
                case .initial:
                    buffer[i] = v
                    i += 1
                    if v == ._slash {
                        state = .slash
                    }
                case .slash:
                    if v != ._slash {
                        buffer[i] = v
                        i += 1
                        state = .initial
                    }
                }
            }
            return i
        }
    }

    internal var _droppingTrailingSlashes: String {
        guard !self.isEmpty else {
            return self
        }
        guard let lastNonSlash = utf8.lastIndex(where: { $0 != ._slash }) else {
            // It's all /'s so just return a single slash
            return "/"
        }
        return String(self[...lastNonSlash])
    }

    private var _standardizingSlashes: String {
        _compressingSlashes()._droppingTrailingSlashes
    }

// MARK: - Filesystem String Extensions

#if !NO_FILESYSTEM

    internal static func homeDirectoryPath(forUser user: String? = nil) -> String {
        #if os(Windows)
        if let user {
            func fallbackUserDirectory() -> String {
                guard let fallback = ProcessInfo.processInfo.environment["ALLUSERSPROFILE"] else {
                    fatalError("Unable to find home directory for user \(user) and ALLUSERSPROFILE environment variable is not set")
                }
                
                return fallback
            }

            guard !user.isEmpty else {
                return fallbackUserDirectory()
            }
            
            return user.withCString(encodedAs: UTF16.self) { pwszUserName in
                var cbSID: DWORD = 0
                var cchReferencedDomainName: DWORD = 0
                var eUse: SID_NAME_USE = SidTypeUnknown
                LookupAccountNameW(nil, pwszUserName, nil, &cbSID, nil, &cchReferencedDomainName, &eUse)
                guard cbSID > 0 else {
                    return fallbackUserDirectory()
                }

                return withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(cbSID)) { pSID in
                    return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(cchReferencedDomainName)) { pwszReferencedDomainName in
                        guard LookupAccountNameW(nil, pwszUserName, pSID.baseAddress, &cbSID, pwszReferencedDomainName.baseAddress, &cchReferencedDomainName, &eUse) else {
                            return fallbackUserDirectory()
                        }

                        var pwszSID: LPWSTR? = nil
                        guard ConvertSidToStringSidW(pSID.baseAddress, &pwszSID) else {
                            fatalError("unable to convert SID to string for user \(user)")
                        }

                        return #"SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\\#(String(decodingCString: pwszSID!, as: UTF16.self))"#.withCString(encodedAs: UTF16.self) { pwszKeyPath in
                            return "ProfileImagePath".withCString(encodedAs: UTF16.self) { pwszKey in
                                var cbData: DWORD = 0
                                RegGetValueW(HKEY_LOCAL_MACHINE, pwszKeyPath, pwszKey, RRF_RT_REG_SZ, nil, nil, &cbData)
                                guard cbData > 0 else {
                                    fatalError("unable to query ProfileImagePath for user \(user)")
                                }
                                return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(cbData)) { pwszData in
                                    guard RegGetValueW(HKEY_LOCAL_MACHINE, pwszKeyPath, pwszKey, RRF_RT_REG_SZ, nil, pwszData.baseAddress, &cbData) == ERROR_SUCCESS else {
                                        fatalError("unable to query ProfileImagePath for user \(user)")
                                    }
                                    return String(decodingCString: pwszData.baseAddress!, as: UTF16.self)
                                }
                            }
                        }

                    }
                }
            }
        }

        var hToken: HANDLE? = nil
        guard OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken) else {
            guard let UserProfile = ProcessInfo.processInfo.environment["UserProfile"] else {
                fatalError("unable to evaluate `%UserProfile%`")
            }
            return UserProfile
        }
        defer { CloseHandle(hToken) }

        var dwcchSize: DWORD = 0
        _ = GetUserProfileDirectoryW(hToken, nil, &dwcchSize)

        return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwcchSize)) {
            var dwcchSize: DWORD = DWORD($0.count)
            guard GetUserProfileDirectoryW(hToken, $0.baseAddress, &dwcchSize) else {
                fatalError("unable to query user profile directory")
            }
            return String(decodingCString: $0.baseAddress!, as: UTF16.self)
        }
        #else // os(Windows)

        #if targetEnvironment(simulator)
        if user == nil, let envValue = getenv("CFFIXED_USER_HOME") ?? getenv("HOME") {
            return String(cString: envValue).standardizingPath
        }
        #endif
        
        // First check CFFIXED_USER_HOME if the environment is not considered tainted
        if let envVar = Platform.getEnvSecure("CFFIXED_USER_HOME") {
            return envVar.standardizingPath
        }
        
        #if !os(WASI) // WASI does not have user concept
        // Next, attempt to find the home directory via getpwnam/getpwuid
        var pass: UnsafeMutablePointer<passwd>?
        if let user {
            pass = getpwnam(user)
        } else {
            // We use the real UID instead of the EUID here when the EUID is the root user (i.e. a process has called seteuid(0))
            // In this instance, we historically do this to ensure a stable home directory location for processes that call seteuid(0)
            pass = getpwuid(Platform.getUGIDs(allowEffectiveRootUID: false).uid)
        }
        
        if let dir = pass?.pointee.pw_dir {
            return String(cString: dir).standardizingPath
        }
        #endif // !os(WASI)

        // Fallback to HOME for the current user if possible
        if user == nil, let home = getenv("HOME") {
            return String(cString: home).standardizingPath
        }
        
        // If all else fails, log and fall back to /var/empty
        return "/var/empty"
        #endif // os(Windows)
    }
    
    // From swift-corelibs-foundation's NSTemporaryDirectory. Internal for now, pending a better public API.
    internal static var temporaryDirectoryPath: String {
        func normalizedPath(with path: String) -> String {
            let result = path._convertingSlashesIfNeeded()
            guard result.utf8.last != ._slash else {
                return result
            }
            return result + "/"
        }
        #if os(Windows)
        let cchLength: DWORD = GetTempPathW(0, nil)
        var wszPath: [WCHAR] = Array<WCHAR>(repeating: 0, count: Int(cchLength + 1))
        guard GetTempPathW(DWORD(wszPath.count), &wszPath) <= cchLength else {
            preconditionFailure("GetTempPathW mutation race")
        }
        return normalizedPath(with: String(decodingCString: wszPath, as: UTF16.self).standardizingPath)
        #else // os(Windows)

        #if canImport(Darwin)
        // If confstr returns 0 it either failed or the variable had no content
        // If the variable had no content, we should continue on below
        // If it fails, we should also silently ignore the error and continue on below. This API can fail for non-programmer reasons such as the device being out of storage space when libSystem attempts to create the directory
        let length: Int = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        if length > 0 {
            let result: String? = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { buffer in
                let finalLength = confstr(_CS_DARWIN_USER_TEMP_DIR, buffer.baseAddress!, buffer.count)
                assert(length == finalLength, "Value of _CS_DARWIN_USER_TEMP_DIR changed?")
                if length > 0 && length < buffer.count {
                    return String(decoding: buffer, as: UTF8.self)
                }
                return nil
            }
            
            if let result {
                return result
            }
        }
        #endif // canImport(Darwin)

        #if !os(WASI)
        if let envValue = Platform.getEnvSecure("TMPDIR") {
            return normalizedPath(with: envValue)
        }
        #endif

        #if os(Android)
        // Bionic uses /data/local/tmp/ as temporary directory. TMPDIR is rarely
        // defined.
        return "/data/local/tmp/"
        #else
        return "/tmp/"
        #endif
        #endif // os(Windows)
    }

    private static let NETWORK_PREFIX: [UInt8] = [._backslash, ._backslash]

    private static let _automountPrefixes = {
        let prefixes: [[UInt8]] = [
            Array("/private/var/automount/".utf8),
            Array("/var/automount/".utf8),
            Array("/private/".utf8)
        ]
        return prefixes
    }()

    private static let _automountExclusionList = {
        let exclusions: [[UInt8]] = [
            Array("/Applications".utf8),
            Array("/Library".utf8),
            Array("/System".utf8),
            Array("/Users".utf8),
            Array("/Volumes".utf8),
            Array("/bin".utf8),
            Array("/cores".utf8),
            Array("/dev".utf8),
            Array("/opt".utf8),
            Array("/private".utf8),
            Array("/sbin".utf8),
            Array("/usr".utf8)
        ]
        return exclusions
    }()

    private var _standardizingPath: String {
        var result = _convertingSlashesIfNeeded()._standardizingSlashes
        let postNetStart = if result.utf8.starts(with: String.NETWORK_PREFIX) {
            result.utf8.firstIndex(of: ._slash) ?? result.endIndex
        } else {
            result.startIndex
        }
        let hasDotDot = result[postNetStart...]._hasDotDotComponent()
        if hasDotDot, let resolved = result._resolvingSymlinksInPath() {
            result = resolved
        }

        result = result._removingDotSegments

        // Automounted paths need to be stripped for various flavors of paths
        for prefix in String._automountPrefixes {
            if result.utf8.starts(with: prefix) {
                let prefixEndSlash = result.utf8.index(result.startIndex, offsetBy: prefix.count - 1)
                let newPath = result[prefixEndSlash...]
                let isExcluded = String._automountExclusionList.contains {
                    newPath._hasPathPrefix($0)
                }
                if !isExcluded && FileManager.default.fileExists(atPath: String(newPath)) {
                    result = String(newPath)
                }
                break
            }
        }
        return result
    }

    var standardizingPath: String {
        expandingTildeInPath._standardizingPath
    }

    var abbreviatingWithTildeInPath: String {
        _convertingSlashesIfNeeded()._abbreviatingWithTildeInPath
    }
    
    private var _abbreviatingWithTildeInPath: String {
        guard !self.isEmpty && self != "/" else { return self }
        let homeDir = String.homeDirectoryPath().utf8
        guard utf8.starts(with: homeDir) else { return self }
        let nextIdxInOriginal = utf8.index(startIndex, offsetBy: homeDir.count)
        guard nextIdxInOriginal == endIndex || utf8[nextIdxInOriginal] == ._slash else { return self }
        return "~" + self[nextIdxInOriginal...]
    }
    
    var expandingTildeInPath: String {
        _convertingSlashesIfNeeded()._expandingTildeInPath
    }
    
    private var _expandingTildeInPath: String {
        guard utf8.first == UInt8(ascii: "~") else { return self }
        var user: String? = nil
        let firstSlash = utf8.firstIndex(of: ._slash) ?? endIndex
        let indexAfterTilde = utf8.index(after: startIndex)
        if firstSlash != indexAfterTilde {
            user = String(self[indexAfterTilde ..< firstSlash])
        }
        let userDir = String.homeDirectoryPath(forUser: user)
        return userDir + self[firstSlash...]
    }
    
    private static func _resolvingSymlinksInPathUsingFullPathAttribute(_ fsRep: UnsafePointer<CChar>) -> String? {
        #if canImport(Darwin)
        var attrs = attrlist()
        attrs.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        attrs.commonattr = attrgroup_t(ATTR_CMN_FULLPATH)
        var buffer = FullPathAttributes()
        guard getattrlist(fsRep, &attrs, &buffer, MemoryLayout<FullPathAttributes>.size, 0) == 0, buffer.fullPathAttr.attr_length > 0 else {
            return nil
        }
        
        let length = Int(buffer.fullPathAttr.attr_length) // Includes null byte
        return withUnsafePointer(to: buffer.fullPathBuf) { pathPtr in
            pathPtr.withMemoryRebound(to: CChar.self, capacity: length) { ccharPtr in
                String(cString: ccharPtr)
            }
        }
        #else
        return nil
        #endif // canImport(Darwin)
    }
    
    func _resolvingSymlinksInPath() -> String? {
        guard !isEmpty else { return nil }
        #if os(Windows)
        return try? self.withNTPathRepresentation {
            let hFile: HANDLE = CreateFileW($0, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, nil)
            if hFile == INVALID_HANDLE_VALUE {
                return nil
            }
            defer { CloseHandle(hFile) }

            let dwLength: DWORD = GetFinalPathNameByHandleW(hFile, nil, 0, VOLUME_NAME_DOS)
            return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
                guard GetFinalPathNameByHandleW(hFile, $0.baseAddress, dwLength, VOLUME_NAME_DOS) == dwLength - 1 else {
                    return nil
                }

                let pathBaseAddress: UnsafePointer<WCHAR>
                if Array($0.prefix(4)) == Array(#"\\?\"#.utf16) {
                    // When using `VOLUME_NAME_DOS`, the returned path uses `\\?\`.
                    pathBaseAddress = UnsafePointer($0.baseAddress!.advanced(by: 4))
                } else {
                    pathBaseAddress = UnsafePointer($0.baseAddress!)
                }
                return String(decodingCString: pathBaseAddress, as: UTF16.self)
            }
        }
        #else // os(Windows)
        return self.withFileSystemRepresentation { fsPtr -> String? in
            guard let fsPtr else { return nil }
            // If not using the cache (which may not require hitting the disk at all if it's warm), try getting the full path from getattrlist.
            // If it succeeds, this approach always returns an absolute path starting from the root. Since this function returns relative paths when given a relative path to a relative symlink, dont use this approach unless the path is absolute.
            
            var path = self
            if URL.isAbsolute(standardizing: &path), let resolved = Self._resolvingSymlinksInPathUsingFullPathAttribute(fsPtr) {
                return resolved
            }
            
            return withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { buffer -> String? in
                buffer.initialize(repeating: 0)
                defer { buffer.deinitialize() }
                var fullLength = Platform.copyCString(dst: buffer.baseAddress!, src: fsPtr, size: FileManager.MAX_PATH_SIZE) + 1 // Includes null byte
                return withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { linkBuffer -> String? in
                    linkBuffer.initialize(repeating: 0)
                    defer { linkBuffer.deinitialize() }
                    var scanLoc = buffer.baseAddress!
                    var links = 0
                    while true {
                        var linkResultLen = 0
                        let lastScanLoc = scanLoc
                        while scanLoc.pointee == 0x2F /* U+002F Solidus (/) */ {
                            scanLoc = scanLoc.advanced(by: 1)
                        }
                        while scanLoc.pointee != 0x2F && scanLoc.pointee != 0 {
                            scanLoc = scanLoc.advanced(by: 1)
                        }
                        let slash = scanLoc.pointee
                        scanLoc.pointee = 0
                        var statBuf = stat()
                        if lstat(buffer.baseAddress!, &statBuf) < 0 {
                            return nil
                        }
                        if mode_t(statBuf.st_mode) & S_IFMT == S_IFLNK {
                            /* Examples:
                             *   fspath == /foo/bar0baz/quux/froboz
                             *   linkx == /tic/tac/toe
                             *   result == /tic/tac/toe/baz/quux/froboz
                             *
                             *   fspath == /foo/bar0baz/quux/froboz
                             *   linkx == tic/tac/toe
                             *   result == /foo/tic/tac/toe/baz/quux/froboz
                             */
                            if links > MAXSYMLINKS {
                                return nil
                            }
                            linkResultLen = readlink(buffer.baseAddress!, linkBuffer.baseAddress!, FileManager.MAX_PATH_SIZE - 1)
                            if linkResultLen < 0 {
                                return nil
                            }
                            linkBuffer[linkResultLen] = 0
                        }
                        
                        scanLoc.pointee = slash
                        if linkResultLen > 0 {
                            links += 1
                            // If the link is not an absolute path, preserve the prefix
                            let preservedPrefixLength = linkBuffer[0] == 0x2F ? 0 : (buffer.baseAddress!.distance(to: lastScanLoc) + 1)
                            
                            let scanLocIdx = buffer.baseAddress!.distance(to: scanLoc)
                            let suffixLength = fullLength - scanLocIdx // Includes null byte
                            if preservedPrefixLength + linkResultLen + suffixLength > FileManager.MAX_PATH_SIZE {
                                return nil
                            }
                            
                            // Shift the suffix + null byte to the correct location
                            let afterSuffixIdx = buffer[(preservedPrefixLength + linkResultLen)...].update(fromContentsOf: buffer[scanLocIdx ..< (fullLength)])
                            
                            // Replace the component with the link
                            _ = buffer[preservedPrefixLength ..< (preservedPrefixLength + linkResultLen)].update(fromContentsOf: linkBuffer[..<linkResultLen])
                            
                            fullLength = afterSuffixIdx
                            scanLoc = linkBuffer[0] == 0x2F ? buffer.baseAddress! : lastScanLoc
                        } else {
                            if scanLoc.pointee == 0 {
                                break
                            }
                        }
                    }
                    return String(cString: buffer.baseAddress!)
                }
            }
        }
        #endif // os(Windows)
    }
    
    var resolvingSymlinksInPath: String {
        var result = expandingTildeInPath
        if let resolved = result._resolvingSymlinksInPath() {
            result = resolved
        }
        return result._standardizingPath
    }

#endif // !NO_FILESYSTEM

}

// MARK: - StringProtocol Helper Extensions

fileprivate enum DotDotState {
    case initial
    case dot
    case dotDot
    case lookingForSlash
}

extension StringProtocol {
    internal func replacing(_ a: UInt8, with b: UInt8) -> String {
        var utf8Array = Array(self.utf8)
        var didReplace = false
        // ~300x faster than Array.replace([UInt8], with: [UInt8]) for one element
        for i in 0..<utf8Array.count {
            if utf8Array[i] == a {
                utf8Array[i] = b
                didReplace = true
            }
        }
        guard didReplace else {
            return String(self)
        }
        return String(unsafeUninitializedCapacity: utf8Array.count) { buffer in
            buffer.initialize(fromContentsOf: utf8Array)
        }
    }

    // Internal for testing purposes
    internal func _hasDotDotComponent() -> Bool {
        guard utf8.count >= 2 else {
            return false
        }

        var state = DotDotState.initial
        for v in utf8 {
            switch state {
            case .initial:
                if v == ._dot {
                    state = .dot
                } else if v == ._slash {
                    continue
                } else {
                    state = .lookingForSlash
                }
            case .dot:
                if v == ._dot {
                    state = .dotDot
                } else if v == ._slash {
                    state = .initial
                } else {
                    state = .lookingForSlash
                }
            case .dotDot:
                if v == ._slash {
                    return true // Starts with "../" or contains "/../"
                } else {
                    state = .lookingForSlash
                }
            case .lookingForSlash:
                if v == ._slash {
                    state = .initial
                } else {
                    continue
                }
            }
        }
        return state == .dotDot // Is ".." or ends with "/.."
    }

    // Returns true if self == prefix or self starts with (prefix + "/")
    internal func _hasPathPrefix(_ prefix: some Collection<UInt8>) -> Bool {
        guard utf8.starts(with: prefix) else {
            return false
        }
        let prefixEnd = utf8.index(startIndex, offsetBy: prefix.count)
        return prefixEnd == endIndex || utf8[prefixEnd] == ._slash
    }
}
