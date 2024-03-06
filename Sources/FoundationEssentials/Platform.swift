//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin

#if FOUNDATION_FRAMEWORK
@_implementationOnly import MachO.dyld
#else
package import MachO.dyld
#endif // FOUNDATION_FRAMEWORK

fileprivate var _pageSize: Int {
    Int(vm_page_size)
}
#elseif canImport(WinSDK)
import WinSDK
fileprivate var _pageSize: Int {
    var sysInfo: SYSTEM_INFO = SYSTEM_INFO()
    GetSystemInfo(&sysInfo)
    return Int(sysInfo.dwPageSize)
}
#elseif os(WASI)
// WebAssembly defines a fixed page size
fileprivate let _pageSize: Int = 65_536
#elseif canImport(Glibc)
import Glibc
fileprivate let _pageSize: Int = Int(getpagesize())
#elseif canImport(C)
fileprivate let _pageSize: Int = Int(getpagesize())
#endif // canImport(Darwin)

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _CShims
@_implementationOnly import CoreFoundation_Private
#else
package import _CShims
#endif

package struct Platform {
    static var pageSize: Int {
        _pageSize
    }

    // FIXME: Windows SEPARATOR
    static let PATH_SEPARATOR: Character = "/"
    static let MAX_HOSTNAME_LENGTH = 1024

    static func roundDownToMultipleOfPageSize(_ size: Int) -> Int {
        return size & ~(self.pageSize - 1)
    }

    static func roundUpToMultipleOfPageSize(_ size: Int) -> Int {
        return (self.pageSize + size - 1) & ~(self.pageSize - 1)
    }

    static func copyMemoryPages(_ source: UnsafeRawPointer, _ dest: UnsafeMutableRawPointer, _ length: Int) {
#if canImport(Darwin)
        if vm_copy(
            mach_task_self_,
            vm_address_t(UInt(bitPattern: source)),
            vm_size_t(length),
            vm_address_t(UInt(bitPattern: dest))) != KERN_SUCCESS {
            memmove(dest, source, length)
        }
#else
        memmove(dest, source, length)
#endif // canImport(Darwin)
    }
}

// MARK: - EUID & EGID

#if !NO_PROCESS
#if canImport(Darwin)
private func _getSVUID() -> uid_t? {
    var kinfo = kinfo_proc()
    var len: size_t = 0
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    let ret = mib.withUnsafeMutableBufferPointer {
        sysctl($0.baseAddress!, u_int($0.count), &kinfo, &len, nil, 0)
    }
    guard ret == 0 else { return nil }
    return kinfo.kp_eproc.e_pcred.p_svuid
}

private var _canChangeUIDs: Bool = {
    let euid = geteuid()
    let uid = getuid()
    let svuid = _getSVUID()
    return uid == 0 || uid != euid || svuid != euid || svuid == nil
}()

private func _lookupUGIDs() -> (uid_t, gid_t) {
    var uRes = uid_t()
    var gRes = gid_t()
    if pthread_getugid_np(&uRes, &gRes) != 0 {
        uRes = geteuid()
        gRes = getegid()
    }
    return (uRes, gRes)
}

private var _cachedUGIDs: (uid_t, gid_t) = {
    _lookupUGIDs()
}()
#endif

extension Platform {
    static func getUGIDs() -> (uid: UInt32, gid: UInt32) {
        #if canImport(Darwin)
        if _canChangeUIDs {
            _lookupUGIDs()
        } else {
            _cachedUGIDs
        }
        #else
        return (uid: geteuid(), gid: getegid())
        #endif
    }
}

// MARK: - Environment Variables
extension Platform {
    static func getEnvSecure(_ name: String) -> String? {
        #if canImport(Glibc)
        if let value = secure_getenv(name) {
            return String(cString: value)
        } else {
            return nil
        }
        #else
        guard issetugid() == 0 else { return nil }
        if let value = getenv(name) {
            return String(cString: value)
        } else {
            return nil
        }
        #endif
    }
}
#endif // !NO_PROCESS

// MARK: - Strings
extension Platform {
    @discardableResult
    package static func copyCString(dst: UnsafeMutablePointer<CChar>, src: UnsafePointer<CChar>, size: Int) -> Int {
        #if canImport(Darwin)
        return strlcpy(dst, src, size)
        #else
        // Glibc doesn't support strlcpy
        let dstBuffer = UnsafeMutableBufferPointer(start: dst, count: size)
        let srcLen = strlen(src)
        let srcBuffer = UnsafeBufferPointer(start: src, count: srcLen + 1)
        var (unwrittenIterator, _) = dstBuffer.update(from: srcBuffer)
        if unwrittenIterator.next() != nil {
            // Destination's space was insufficient, ensure it is truncated and null terminated
            dstBuffer[dstBuffer.count - 1] = 0
        }
        return srcLen
        #endif
    }
}

// MARK: - Hostname
extension Platform {
#if !FOUNDATION_FRAMEWORK
    static func getHostname() -> String {
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: Platform.MAX_HOSTNAME_LENGTH + 1) {
            guard gethostname($0.baseAddress!, Platform.MAX_HOSTNAME_LENGTH) == 0 else {
                return ""
            }
            return String(cString: $0.baseAddress!)
        }
    }
#endif // !FOUNDATION_FRAMEWORK
}

// MARK: - Executable Path
extension Platform {
    static func getFullExecutablePath() -> String? {
#if FOUNDATION_FRAMEWORK && !NO_FILESYSTEM
        guard let cPath = _CFProcessPath() else {
            return nil
        }
        return String(cString: cPath).standardizingPath
#elseif canImport(Darwin)
        // Apple platforms, first check for env override
        #if os(macOS)
        if let override = Self.getEnvSecure("CFProcessPath") {
            return override.standardizingPath
        }
        #endif

        // use _NSGetExecutablePath
        return withUnsafeTemporaryAllocation(
            of: CChar.self, capacity: FileManager.MAX_PATH_SIZE
        ) { buffer -> String? in
            var size: UInt32 = UInt32(FileManager.MAX_PATH_SIZE)
            guard _NSGetExecutablePath(buffer.baseAddress!, &size) == 0 else {
                return nil
            }
            #if NO_FILESYSTEM
            return String(cString: buffer.baseAddress!)
            #else
            return String(cString: buffer.baseAddress!).standardizingPath
            #endif
        }
#elseif os(Linux)
        // For Linux, read /proc/self/exe
        return try? FileManager.default.destinationOfSymbolicLink(
            atPath: "/proc/self/exe").standardizingPath
#else
        // TODO: Implement for other platforms
        return nil
#endif
    }
}
