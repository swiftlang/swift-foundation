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

internal import _FoundationCShims

#if canImport(Darwin)
import Darwin
internal import MachO.dyld

fileprivate let _pageSize: Int = {
    Int(_platform_shims_vm_size())
}()
#elseif canImport(WinSDK)
import WinSDK
fileprivate let _pageSize: Int = {
    var sysInfo: SYSTEM_INFO = SYSTEM_INFO()
    GetSystemInfo(&sysInfo)
    return Int(sysInfo.dwPageSize)
}()
#elseif os(WASI)
// WebAssembly defines a fixed page size
fileprivate let _pageSize: Int = 65_536
#elseif os(Android)
import Bionic
import unistd
fileprivate let _pageSize: Int = Int(getpagesize())
#elseif canImport(Glibc)
import Glibc
fileprivate let _pageSize: Int = Int(getpagesize())
#elseif canImport(Musl)
import Musl
fileprivate let _pageSize: Int = Int(getpagesize())
#elseif canImport(C)
fileprivate let _pageSize: Int = Int(getpagesize())
#endif // canImport(Darwin)

#if FOUNDATION_FRAMEWORK
internal import CoreFoundation_Private
#endif


package struct Platform {
    static var pageSize: Int {
        _pageSize
    }

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
            _platform_mach_task_self(),
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

private let _canChangeUIDs: Bool = {
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

private let _cachedUGIDs: (uid_t, gid_t) = {
    _lookupUGIDs()
}()
#endif

#if !os(Windows) && !os(WASI)
extension Platform {
    private static var ROOT_USER: UInt32 { 0 }
    static func getUGIDs(allowEffectiveRootUID: Bool = true) -> (uid: UInt32, gid: UInt32) {
        var result: (uid: UInt32, gid: UInt32)
        #if canImport(Darwin)
        if _canChangeUIDs {
            result = _lookupUGIDs()
        } else {
            result = _cachedUGIDs
        }
        #else
        result = (uid: geteuid(), gid: getegid())
        #endif
        // Some callers need to use the real UID in cases where a process has called seteuid(0)
        // If that is the case for this caller, and the eUID is the root user, return the real UID instead
        if !allowEffectiveRootUID && result.uid == Self.ROOT_USER {
            result.uid = getuid()
        }
        return result
    }
}
#endif

// MARK: - Environment Variables
extension Platform {
    static func getEnvSecure(_ name: String) -> String? {
        #if canImport(Glibc)
        if let value = secure_getenv(name) {
            return String(cString: value)
        } else {
            return nil
        }
        #elseif os(Windows)
        var hToken: HANDLE? = nil
        guard OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken) else {
            return nil
        }
        defer { CloseHandle(hToken) }

        var dwLength: DWORD = 0
        var elevation: TOKEN_ELEVATION = .init()
        guard GetTokenInformation(hToken, TokenElevation, &elevation, DWORD(MemoryLayout<TOKEN_ELEVATION>.size), &dwLength) else {
            return nil
        }

        if elevation.TokenIsElevated == 0 { return nil }

        return name.withCString(encodedAs: UTF16.self) { pwszName in
            let dwLength = GetEnvironmentVariableW(pwszName, nil, 0)
            return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) { lpBuffer in
                guard GetEnvironmentVariableW(pwszName, lpBuffer.baseAddress, dwLength) == dwLength - 1 else {
                    return nil
                }
                return String(decodingCString: lpBuffer.baseAddress!, as: UTF16.self)
            }
        }
        #else
        // FIXME: bionic implements this as `return 0;` and does not expose the
        // function via headers. We should be able to shim this and use the call
        // if it is available.
#if !os(Android) && !os(WASI)
        guard issetugid() == 0 else { return nil }
#endif
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
        #if canImport(Darwin) || canImport(Android)
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
#if os(Windows)
        var dwLength: DWORD = 0
        _ = GetComputerNameExW(ComputerNameDnsHostname, nil, &dwLength)
        return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
          dwLength -= 1 // null-terminator reservation
          guard GetComputerNameExW(ComputerNameDnsHostname, $0.baseAddress!, &dwLength) else {
            return "localhost"
          }
          return String(decodingCString: $0.baseAddress!, as: UTF16.self)
        }
#elseif os(WASI) // WASI does not have uname
        return "localhost"
#else
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: Platform.MAX_HOSTNAME_LENGTH + 1) {
            guard gethostname($0.baseAddress!, numericCast(Platform.MAX_HOSTNAME_LENGTH)) == 0 else {
                return "localhost"
            }
            return String(cString: $0.baseAddress!)
        }
#endif
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
#elseif os(Linux) || os(Android)
        // For Linux, read /proc/self/exe
        return try? FileManager.default.destinationOfSymbolicLink(
            atPath: "/proc/self/exe").standardizingPath
#elseif os(Windows)
        let hFile = GetModuleHandleW(nil)
        let dwLength: DWORD = GetFinalPathNameByHandleW(hFile, nil, 0, FILE_NAME_NORMALIZED)
        guard dwLength > 0 else { return nil }
        return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) { lpBuffer in
            guard GetFinalPathNameByHandleW(hFile, lpBuffer.baseAddress, dwLength, FILE_NAME_NORMALIZED) == dwLength - 1 else {
                return nil
            }

            // The `GetFinalPathNameByHandleW` function will normalise the path
            // for us as part of the query. This allows us to avoid having to
            // standardize the path ourselves.
            return String(decodingCString: lpBuffer.baseAddress!, as: UTF16.self)
        }
#else
        // TODO: Implement for other platforms
        return nil
#endif
    }
}
