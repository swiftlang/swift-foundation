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
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

internal import _CShims

extension String {
    internal func deletingLastPathComponent() -> String {
        let lastSlash = self.lastIndex { $0 == "/" }
        guard let lastSlash else {
            // No slash
            return ""
        }
        
        if lastSlash == startIndex {
            // Only a first slash, return a bare slash.
            return "/"
        }
        
        if lastSlash == index(before: endIndex) {
            // This is a trailing slash. Ignore it.
            let beforeLastSlash = self[startIndex..<lastSlash].lastIndex { $0 == "/" }
            if let beforeLastSlash {
                return String(self[startIndex..<beforeLastSlash])
            } else {
                // No other slash. Return empty string.
                return ""
            }
        } else {
            return String(self[startIndex..<lastSlash])
        }
    }
        
    internal func appendingPathComponent(_ component: String) -> String {
        var result = self
        if !component.isEmpty {
            var needsSlash = true
            if isEmpty {
                needsSlash = false
            } else if count == 1 {
                needsSlash = first! != "/"
            } else if count == 2 {
                // "net"
                needsSlash = !(self[startIndex] == "\\" && self[index(after: startIndex)] == "\\")
            }
            
            if needsSlash {
                result = result + "/"
            }
            
            result = result + component
        }
        
        result = result.reduce(into: "") { partialResult, c in
            guard c == "/" else {
                partialResult += String(c)
                return
            }
            
            guard !partialResult.isEmpty else {
                partialResult += "/"
                return
            }
            
            let lastCharacter = partialResult.last!
            if lastCharacter != "/" {
                // Append the slash
                partialResult += "/"
            }
        }
        
        if result.isEmpty { return "" }
        
        if result.last! != "/" {
            return result
        }
        
        var idx = result.endIndex
        idx = result.index(before: idx)
        while idx != result.startIndex && result[idx] == "/" {
            idx = result.index(before: idx)
        }
        
        return String(result[result.startIndex..<result.index(after: idx)])
    }

    internal var lastPathComponent: String {
        let lastSlash = self.lastIndex { $0 == "/" }
        guard let lastSlash else {
            // No slash, just return self
            return self
        }
        
        if lastSlash == startIndex {
            if count == 1 {
                // Only a first slash, return a bare slash.
                return "/"
            } else {
                return String(self[index(after: startIndex)..<endIndex])
            }
        }
        
        if lastSlash == index(before: endIndex) {
            // This is a trailing slash. Ignore it and all slashes that directly precede it.
            let lastNonSlash = self[startIndex..<lastSlash].lastIndex { $0 != "/" }
            guard let lastNonSlash else {
                // String is all slashes, return a bare slash.
                return "/"
            }
            let slashBeforeLastComponent = self[startIndex..<lastNonSlash].lastIndex { $0 == "/" }
            if let slashBeforeLastComponent {
                return String(self[index(after: slashBeforeLastComponent)...lastNonSlash])
            } else {
                // No other slash. Return string up to the last non-slash character.
                return String(self[startIndex...lastNonSlash])
            }
        } else {
            return String(self[index(after: lastSlash)..<endIndex])
        }
    }
    
    #if !NO_FILESYSTEM
    internal static func homeDirectoryPath(forUser user: String? = nil) -> String {
        #if targetEnvironment(simulator)
        if user == nil, let envValue = getenv("CFFIXED_USER_HOME") ?? getenv("HOME") {
            return String(cString: envValue).standardizingPath
        }
        #endif
        
        // First check CFFIXED_USER_HOME if the environment is not considered tainted
        if let envVar = Platform.getEnvSecure("CFFIXED_USER_HOME") {
            return envVar.standardizingPath
        }
        
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
        
        // Fallback to HOME for the current user if possible
        if user == nil, let home = getenv("HOME") {
            return String(cString: home).standardizingPath
        }
        
        // If all else fails, log and fall back to /var/empty
        return "/var/empty"
    }
    
    // From swift-corelibs-foundation's NSTemporaryDirectory. Internal for now, pending a better public API.
    internal static var temporaryDirectoryPath: String {
#if os(Windows)
        let validPathSeps: [Character] = ["\\", "/"]
#else
        let validPathSeps: [Character] = ["/"]
#endif
        
        func normalizedPath(with path: String) -> String {
            if validPathSeps.contains(where: { path.hasSuffix(String($0)) }) {
                return path
            } else {
                return path + String(validPathSeps.last!)
            }
        }
#if os(Windows)
        let cchLength: DWORD = GetTempPathW(0, nil)
        var wszPath: [WCHAR] = Array<WCHAR>(repeating: 0, count: Int(cchLength + 1))
        guard GetTempPathW(DWORD(wszPath.count), &wszPath) <= cchLength else {
            preconditionFailure("GetTempPathW mutation race")
        }
        return normalizedPath(with: String(decodingCString: wszPath, as: UTF16.self).standardizingPath)
#else
#if canImport(Darwin)
        let safe_confstr = { (name: Int32, buf: UnsafeMutablePointer<UInt8>?, len: Int) -> Int in
            // POSIX moment of weird: confstr() is one of those annoying APIs which
            // can return zero for both error and non-error conditions, so the only
            // way to disambiguate is to put errno in a known state before calling.
            errno = 0
            let result = confstr(name, buf, len)
            
            // result == 0 is only error if errno is not zero. But, if there was an
            // error, bail; all possible errors from confstr() are Very Bad Things.
            let err = errno // only read errno once in the failure case.
            precondition(result > 0 || err == 0, "Unexpected confstr() error: \(err)")
            
            // This is extreme paranoia and should never happen; this would mean
            // confstr() returned < 0, which would only happen for impossibly long
            // sizes of value or long-dead versions of the OS.
            assert(result >= 0, "confstr() returned impossible result: \(result)")
            
            return result
        }
        
        let length: Int = safe_confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        if length > 0 {
            var buffer: [UInt8] = .init(repeating: 0, count: length)
            let final_length = safe_confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count)
            
            assert(length == final_length, "Value of _CS_DARWIN_USER_TEMP_DIR changed?")
            if length > 0 && length < buffer.count {
                return buffer.withUnsafeBufferPointer { b in
                    String(bytes: b, encoding: .utf8)!
                }
            }
        }
#endif
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
#endif
    }
    
    private func _transmutingCompressingSlashes(replacement: String = "/") -> String {
        self.replacing(#//+/#, with: { _ in replacement })
    }
    
    private var _droppingTrailingSlashes: String {
        guard let lastNonSlash = self.lastIndex(where: { $0 != "/"}) else {
            // It's all /'s so just return a single slash
            return "/"
        }
        return String(self[...lastNonSlash])
    }
    
    static var NETWORK_PREFIX: String { #"\\"# }
    
    private var _standardizingPath: String {
        var result = _transmutingCompressingSlashes()._droppingTrailingSlashes
        let postNetStart = if result.starts(with: String.NETWORK_PREFIX) {
            result.firstIndex(of: "/") ?? result.endIndex
        } else {
            result.startIndex
        }
        let dotDotRegex = #/[^/]\.\.[/$]/#
        let hasDotDot = result[postNetStart...].contains(dotDotRegex)
        if hasDotDot, let resolved = result._resolvingSymlinksInPath() {
            result = resolved
        }
        
        var components = result.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return "/" }
        
        // Remove all "." components
        components.removeAll { $0 == "." }
        
        // Since result must be absolute, remove all leading ".." components
        var toSearchFrom = 0
        while let dotDotIdx = components[toSearchFrom...].firstIndex(of: "..") {
            components.remove(at: dotDotIdx)
            toSearchFrom = dotDotIdx
            if dotDotIdx > 0 {
                components.remove(at: dotDotIdx - 1)
                toSearchFrom -= 1
            }
        }
        
        // Retain any leading slashes but drop any otherwise empty components
        result = components.enumerated().filter { $0 == 0 || !$1.isEmpty }.map(\.1).joined(separator: "/")
        
        // Automounted paths need to be stripped for various flavors of paths
        let exclusionList = ["/Applications", "/Library", "/System", "/Users", "/Volumes", "/bin", "/cores", "/dev", "/opt", "/private", "/sbin", "/usr"]
        for path in ["/private/var/automount", "/var/automount", "/private"] {
            if result.starts(with: "\(path)/") {
                let newPath = String(result.dropFirst(path.count))
                let isExcluded = exclusionList.contains {
                    newPath == $0 || newPath.starts(with: "\($0)/")
                }
                if !isExcluded && FileManager.default.fileExists(atPath: newPath) {
                    result = newPath
                }
                break
            }
        }
        return result
    }
    
    var standardizingPath: String {
        expandingTildeInPath._standardizingPath
    }
    #endif // !NO_FILESYSTEM
    
    // _NSPathComponents
    var pathComponents: [String] {
        var components = self.components(separatedBy: "/").filter { !$0.isEmpty }
        if self.first == "/" {
            components.insert("/", at: 0)
        }
        if self.last == "/" && self.count > 1 {
            components.append("/")
        }
        return components
    }
    
    #if !NO_FILESYSTEM
    var abbreviatingWithTildeInPath: String {
        guard !self.isEmpty && self != "/" else { return self }
        let homeDir = String.homeDirectoryPath()
        guard self.starts(with: homeDir) else { return self }
        let nextIdxInOriginal = self.unicodeScalars.index(self.startIndex, offsetBy: homeDir.unicodeScalars.count)
        guard nextIdxInOriginal == self.endIndex || self[nextIdxInOriginal] == "/" else { return self }
        return "~" + self[nextIdxInOriginal...]
    }
    
    var expandingTildeInPath: String {
        guard self.first == "~" else { return self }
        var user: String? = nil
        let firstSlash = self.firstIndex(of: "/") ?? self.endIndex
        let indexAfterTilde = self.index(after: self.startIndex)
        if firstSlash != indexAfterTilde {
            user = String(self[indexAfterTilde ..< firstSlash])
        }
        let userDir = String.homeDirectoryPath(forUser: user)
        return userDir + self[firstSlash...]
    }
    
    private var _isAbsolutePath: Bool {
        first == "~" || first == "/"
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
        #endif
    }
    
    func _resolvingSymlinksInPath() -> String? {
        guard !isEmpty else { return nil }
        return self.withFileSystemRepresentation { fsPtr -> String? in
            guard let fsPtr else { return nil }
            // If not using the cache (which may not require hitting the disk at all if it's warm), try getting the full path from getattrlist.
            // If it succeeds, this approach always returns an absolute path starting from the root. Since this function returns relative paths when given a relative path to a relative symlink, dont use this approach unless the path is absolute.
            
            if self._isAbsolutePath, let resolved = Self._resolvingSymlinksInPathUsingFullPathAttribute(fsPtr) {
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
                        if st_mode(statBuf.st_mode) & st_mode(S_IFMT) == st_mode(S_IFLNK) {
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
