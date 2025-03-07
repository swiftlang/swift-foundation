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
#elseif canImport(Android)
@preconcurrency import Android
fileprivate let _pageSize: Int = Int(getpagesize())
#elseif canImport(Glibc)
@preconcurrency import Glibc
fileprivate let _pageSize: Int = Int(getpagesize())
#elseif canImport(Musl)
@preconcurrency import Musl
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
    
    #if canImport(Darwin)
    typealias Operation<Input, Output> = (Input, UnsafeMutablePointer<Output>?, UnsafeMutablePointer<CChar>?, Int, UnsafeMutablePointer<UnsafeMutablePointer<Output>?>?) -> Int32
    #else
    typealias Operation<Input, Output> = (Input, UnsafeMutablePointer<Output>, UnsafeMutablePointer<CChar>, Int, UnsafeMutablePointer<UnsafeMutablePointer<Output>?>) -> Int32
    #endif
    
    private static func withUserGroupBuffer<Input, Output, R>(_ input: Input, _ output: Output, sizeProperty: Int32, operation: Operation<Input, Output>, block: (Output) throws -> R?) rethrows -> R? {
        var bufferLen = sysconf(sizeProperty)
        if bufferLen == -1 {
            bufferLen = 4096 // Generous default size estimate
        }
        return try withUnsafeTemporaryAllocation(of: CChar.self, capacity: bufferLen) {
            var result = output
            var ptr: UnsafeMutablePointer<Output>?
            let error = operation(input, &result, $0.baseAddress!, bufferLen, &ptr)
            guard error == 0 && ptr != nil else {
                return nil
            }
            return try block(result)
        }
    }
    
    static func uid(forName name: String) -> uid_t? {
        withUserGroupBuffer(name, passwd(), sizeProperty: Int32(_SC_GETPW_R_SIZE_MAX), operation: getpwnam_r) {
            $0.pw_uid
        }
    }
    
    static func gid(forName name: String) -> uid_t? {
        withUserGroupBuffer(name, group(), sizeProperty: Int32(_SC_GETGR_R_SIZE_MAX), operation: getgrnam_r) {
            $0.gr_gid
        }
    }
    
    static func name(forUID uid: uid_t) -> String? {
        withUserGroupBuffer(uid, passwd(), sizeProperty: Int32(_SC_GETPW_R_SIZE_MAX), operation: getpwuid_r) {
            // Android's pw_name `char *`` is nullable when it should be non-null.
            // FIXME: avoid the coerce cast workaround once https://github.com/android/ndk/issues/2098 is fixed.
            let pw_name: UnsafeMutablePointer<CChar>? = $0.pw_name
            return pw_name.flatMap { String(cString: $0) }
        }
    }
    
    static func fullName(forUID uid: uid_t) -> String? {
        withUserGroupBuffer(uid, passwd(), sizeProperty: Int32(_SC_GETPW_R_SIZE_MAX), operation: getpwuid_r) {
#if os(Android) && _pointerBitWidth(_32)
            // pw_gecos isn't available on 32-bit Android.
            let pw_gecos: UnsafeMutablePointer<CChar>? = nil
#else
            // Android's pw_gecos `char *`` is nullable, so always coerce to a nullable pointer
            // in order to be compatible with Android.
            let pw_gecos: UnsafeMutablePointer<CChar>? = $0.pw_gecos
#endif
            return pw_gecos.flatMap { String(cString: $0) }
        }
    }
    
    static func name(forGID gid: gid_t) -> String? {
        withUserGroupBuffer(gid, group(), sizeProperty: Int32(_SC_GETGR_R_SIZE_MAX), operation: getgrgid_r) {
            // Android's gr_name `char *`` is nullable when it should be non-null.
            // FIXME: avoid the coerce cast workaround once https://github.com/android/ndk/issues/2098 is fixed.
            let gr_name: UnsafeMutablePointer<CChar>? = $0.gr_name
            return gr_name.flatMap { String(cString: $0) }
        }
    }
    
    static func homeDirectory(forUserName userName: String) -> String? {
        withUserGroupBuffer(userName, passwd(), sizeProperty: Int32(_SC_GETPW_R_SIZE_MAX), operation: getpwnam_r) {
            // Android's pw_dir `char *`` is nullable when it should be non-null.
            // FIXME: avoid the coerce cast workaround once https://github.com/android/ndk/issues/2098 is fixed.
            let pw_dir: UnsafeMutablePointer<CChar>? = $0.pw_dir
            return pw_dir.flatMap { String(cString: $0) }
        }
    }
    
    static func homeDirectory(forUID uid: uid_t) -> String? {
        withUserGroupBuffer(uid, passwd(), sizeProperty: Int32(_SC_GETPW_R_SIZE_MAX), operation: getpwuid_r) {
            // Android's pw_dir `char *`` is nullable when it should be non-null.
            // FIXME: avoid the coerce cast workaround once https://github.com/android/ndk/issues/2098 is fixed.
            let pw_dir: UnsafeMutablePointer<CChar>? = $0.pw_dir
            return pw_dir.flatMap { String(cString: $0) }
        }
    }
}
#endif

// MARK: - Environment Variables
extension Platform {
    static func getEnvSecure(_ name: String) -> String? {
        #if canImport(Glibc) && !os(OpenBSD)
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
#if !canImport(Android) && !os(WASI)
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
