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
#if FOUNDATION_FRAMEWORK
@_implementationOnly import os
#else
package import os
#endif
#elseif canImport(Glibc)
import Glibc
#endif

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
            // This is a trailing slash. Ignore it.
            let beforeLastSlash = self[startIndex..<lastSlash].lastIndex { $0 == "/" }
            if let beforeLastSlash {
                return String(self[index(after: beforeLastSlash)..<lastSlash])
            } else {
                // No other slash. Return string minus that slash.
                return String(self[startIndex..<lastSlash])
            }
        } else {
            return String(self[index(after: lastSlash)..<endIndex])
        }
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
#if os(Android)
        // Bionic uses /data/local/tmp/ as temporary directory. TMPDIR is rarely
        // defined.
        return "/data/local/tmp/"
#else
        return "/tmp/"
#endif
#endif
    }

}
