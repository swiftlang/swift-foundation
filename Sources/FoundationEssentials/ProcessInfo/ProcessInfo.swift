//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal import _FoundationCShims

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Bionic
import unistd
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import WinSDK
#elseif os(WASI)
import WASILibc
#endif

#if !NO_PROCESS

final class _ProcessInfo: Sendable {
    static let processInfo: _ProcessInfo = _ProcessInfo()

    private let state: LockedState<State>
    // Host name resolution CAN take infinite time,
    // so at the bare min do not share the lock with the
    // rest of the state
    private let _hostName: LockedState<String?>

    internal init() {
        let state: State = State()
        self.state = LockedState(initialState: state)
        self._hostName = LockedState(initialState: nil)
    }

    var arguments: [String] {
        // Bin compat: always use full executable path
        // for arg0. CommandLine.arguments.first may not
        // always be the full executable path, most
        // noticeably when you launch the process via `$PATH`
        // instead of full path.
        return state.withLock {
            if let existing = $0.arguments {
                return existing
            }
            var current = CommandLine.arguments
            // Replace the process path
            if let fullPath = Platform.getFullExecutablePath() {
                // Swift's CommandLine.arguments can be empty
                if current.isEmpty {
                    current = [fullPath]
                } else {
                    current[0] = fullPath
                }
            }
            $0.arguments = current
            return current
        }
    }

    var environment: [String : String] {
        return withCopiedEnv { environments in
            var results: [String : String] = [:]
            for env in environments {
                let environmentString = String(cString: env)

#if os(Windows)
                // Windows GetEnvironmentStringsW API can return
                // magic environment variables set by the cmd shell
                // that starts with `=`
                // We should exclude these values
                if environmentString.utf8.first == ._equal {
                    continue
                }
#endif // os(Windows)

                guard let delimiter = environmentString.firstIndex(of: "=") else {
                    continue
                }

                let key = String(environmentString[environmentString.startIndex ..< delimiter])
                let value = String(environmentString[environmentString.index(after: delimiter) ..< environmentString.endIndex])
                results[key] = value
            }
            return results
        }
    }

    private func withCopiedEnv<R>(_ body: ([UnsafeMutablePointer<CChar>]) -> R) -> R {
        var values: [UnsafeMutablePointer<CChar>] = []
#if os(Windows)
        guard let pwszEnvironmentBlock = GetEnvironmentStringsW() else {
            return body([])
        }
        defer { FreeEnvironmentStringsW(pwszEnvironmentBlock) }

        var pwszEnvironmentEntry: LPWCH? = pwszEnvironmentBlock
        while let value = pwszEnvironmentEntry {
            let entry = String(decodingCString: value, as: UTF16.self)
            if entry.isEmpty { break }
            values.append(entry.withCString { _strdup($0)! })
            pwszEnvironmentEntry = pwszEnvironmentEntry?.advanced(by: wcslen(value) + 1)
        }
#else
        // This lock is taken by calls to getenv, so we want as few callouts to other code as possible here.
        _platform_shims_lock_environ()
        guard let environments: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> =
                _platform_shims_get_environ() else {
            _platform_shims_unlock_environ()
            return body([])
        }
        var curr = environments
        while let value = curr.pointee {
            values.append(strdup(value))
            curr = curr.advanced(by: 1)
        }
        _platform_shims_unlock_environ()
#endif
        defer { values.forEach { free($0) } }
        return body(values)
    }

    var globallyUniqueString: String {
        let uuid = UUID().uuidString
        let pid = processIdentifier
#if canImport(Darwin)
        let time: UInt64 = mach_absolute_time()
#elseif os(Windows)
        var ullTime: ULONGLONG = 0
        QueryUnbiasedInterruptTimePrecise(&ullTime)
        let time: UInt64 = ullTime
#else
        var ts: timespec = timespec()
        #if os(FreeBSD) || os(OpenBSD)
        clock_gettime(CLOCK_MONOTONIC, &ts)
        #else
        clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
        #endif
        let time: UInt64 = UInt64(ts.tv_sec) * 1000000000 + UInt64(ts.tv_nsec)
#endif
        let timeString = String(time, radix: 16, uppercase: true)
        let padding = String(repeating: "0", count: 16 - timeString.count)
        return "\(uuid)-\(pid)-\(padding)\(timeString)"
    }

    var processIdentifier: Int32 {
#if os(Windows)
        return Int32(bitPattern: UInt32(GetProcessId(GetCurrentProcess())))
#else
        return Int32(getpid())
#endif
    }

    var processName: String {
        get {
            return state.withLock {
                if let name = $0.processName {
                    return name
                }
                let processName = _ProcessInfo._getProcessName()
                $0.processName = processName
                return processName
            }
        }
        set {
            state.withLock{ $0.processName = newValue }
        }
    }

    var userName: String {
#if canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
        // Darwin and Linux
        let (euid, _) = Platform.getUGIDs()
        if let username = Platform.name(forUID: euid) {
            return username
        } else if let username = self.environment["USER"] {
            return username
        }
        return ""
#elseif os(WASI)
        // WASI does not have user concept
        return ""
#elseif os(Windows)
        var dwSize: DWORD = 0
        _ = GetUserNameW(nil, &dwSize)

        return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwSize)) {
            guard GetUserNameW($0.baseAddress!, &dwSize) else {
                return "USERNAME".withCString(encodedAs: UTF16.self) { pwszName in
                    let dwLength = GetEnvironmentVariableW(pwszName, nil, 0)
                    return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) { lpBuffer in
                        guard GetEnvironmentVariableW(pwszName, lpBuffer.baseAddress, dwLength) == dwLength - 1 else {
                            return ""
                        }
                        return String(decodingCString: lpBuffer.baseAddress!, as: UTF16.self)
                    }
                }
            }
            return String(decodingCString: $0.baseAddress!, as: UTF16.self)
        }
#endif
    }

    var fullUserName: String {
#if canImport(Android) && (arch(i386) || arch(arm))
        // On LP32 Android, pw_gecos doesn't exist and is presumed to be NULL.
        return ""
#elseif canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
        let (euid, _) = Platform.getUGIDs()
        if let fullName = Platform.fullName(forUID: euid) {
            return fullName
        }
        return ""
#elseif os(WASI)
        return ""
#elseif os(Windows)
        var ulLength: ULONG = 0
        _ = GetUserNameExW(NameDisplay, nil, &ulLength)

        return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(ulLength)) { wszBuffer in
            guard GetUserNameExW(NameDisplay, wszBuffer.baseAddress!, &ulLength) == 0 else {
                return ""
            }
            return String(decoding: wszBuffer.prefix(Int(ulLength)), as: UTF16.self)
        }
#endif
    }

#if canImport(Darwin)
    private var _systemClockTickRate: (ticksPerSecond: TimeInterval, secondsPerTick: TimeInterval) {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        let tps = (1.0E9 / TimeInterval(info.numer)) * TimeInterval(info.denom)
        let spt = 1.0 / tps
        return (ticksPerSecond: tps, secondsPerTick: spt)
    }
#endif
}

// MARK: - Getting Host Information
extension _ProcessInfo {
    var hostName: String {
        return _hostName.withLock {
            if let name = $0 {
                return name
            }
            // Resolve hostname
            $0 = Platform.getHostname()
            return $0!
        }
    }
    
#if os(Windows)
    internal var _rawOSVersion: RTL_OSVERSIONINFOEXW? {
        guard let ntdll = "ntdll.dll".withCString(encodedAs: UTF16.self, LoadLibraryW) else {
            return nil
        }
        defer { FreeLibrary(ntdll) }
        typealias RTLGetVersionTy = @convention(c) (UnsafeMutablePointer<RTL_OSVERSIONINFOEXW>) -> NTSTATUS
        guard let pfnRTLGetVersion = unsafeBitCast(GetProcAddress(ntdll, "RtlGetVersion"), to: Optional<RTLGetVersionTy>.self) else {
            return nil
        }
        var osVersionInfo = RTL_OSVERSIONINFOEXW()
        osVersionInfo.dwOSVersionInfoSize = DWORD(MemoryLayout<RTL_OSVERSIONINFOEXW>.size)
        guard pfnRTLGetVersion(&osVersionInfo) == 0 else {
            return nil
        }
        return osVersionInfo
    }
#endif

    var operatingSystemVersionString: String {
#if os(macOS)
        var versionString = "macOS"
#elseif os(Linux)
        if let osReleaseContents = try? Data(contentsOf: URL(filePath: "/etc/os-release", directoryHint: .notDirectory)) {
            let strContents = String(decoding: osReleaseContents, as: UTF8.self)
            if let name = strContents.split(separator: "\n").first(where: { $0.hasPrefix("PRETTY_NAME=") }) {
                // This is extremely simplistic but manages to work for all known cases.
                return String(name.dropFirst("PRETTY_NAME=".count)._trimmingCharacters(while: { $0 == "\"" }))
            }
        }
        
        // Okay, we can't get a distro name, so try for generic info.
        var versionString = "Linux"
#elseif os(Windows)
        guard let osVersionInfo = self._rawOSVersion else {
            return "Windows"
        }

        // Windows has no canonical way to turn the fairly complex `RTL_OSVERSIONINFOW` version info into a string. We
        // do our best here to construct something consistent. Unfortunately, to provide a useful result, this requires
        // hardcoding several of the somewhat ambiguous values in the table provided here:
        //  https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/ns-wdm-_osversioninfoexw#remarks
        let release = switch (osVersionInfo.dwMajorVersion, osVersionInfo.dwMinorVersion, osVersionInfo.dwBuildNumber) {
        case (5, 0, _): "2000"
        case (5, 1, _): "XP"
        case (5, 2, _) where osVersionInfo.wProductType == VER_NT_WORKSTATION: "XP Professional x64"
        case (5, 2, _) where osVersionInfo.wSuiteMask == VER_SUITE_WH_SERVER: "Home Server"
        case (5, 2, _): "Server 2003"
        case (6, 0, _) where osVersionInfo.wProductType == VER_NT_WORKSTATION: "Vista"
        case (6, 0, _): "Server 2008"
        case (6, 1, _) where osVersionInfo.wProductType == VER_NT_WORKSTATION: "7"
        case (6, 1, _): "Server 2008 R2"
        case (6, 2, _) where osVersionInfo.wProductType == VER_NT_WORKSTATION: "8"
        case (6, 2, _): "Server 2012"
        case (6, 3, _) where osVersionInfo.wProductType == VER_NT_WORKSTATION: "8.1"
        case (6, 3, _): "Server 2012 R2" // We assume the "10,0" numbers in the table for this are a typo
        case (10, 0, ..<22000) where osVersionInfo.wProductType == VER_NT_WORKSTATION: "10"
        case (10, 0, 22000...) where osVersionInfo.wProductType == VER_NT_WORKSTATION: "11"
        case (10, 0, _): "Server 2019" // The table gives identical values for 2016 and 2019, so we just assume 2019 here
        case let (maj, min, _): "Unknown (\(maj).\(min))" // If all else fails, just give the raw version number
        }
        // For now we ignore the `szCSDVersion`, `wServicePackMajor`, and `wServicePackMinor` values.
        return "Windows \(release) (build \(osVersionInfo.dwBuildNumber))"
#elseif os(FreeBSD)
        // Try to get a release version from `uname -r`.
        var versionString = "FreeBSD"
        var utsNameBuffer = utsname()
        if uname(&utsNameBuffer) == 0 {
            let release = withUnsafePointer(to: &utsNameBuffer.release.0) { String(cString: $0) }
            if !release.isEmpty {
                versionString += " \(release)"
            }
        }
        return versionString
#elseif os(OpenBSD)
        // TODO: `uname -r` probably works here too.
        return "OpenBSD"
#elseif os(Android)
        /// In theory, we need to do something like this:
        ///
        ///     var versionString = "Android"
        ///     let property = String(unsafeUninitializedCapacity: PROP_VALUE_MAX) { buf in
        ///         __system_property_get("ro.build.description", buf.baseAddress!)
        ///     }
        ///     if !property.isEmpty {
        ///         versionString += " \(property)"
        ///     }
        ///     return versionString
        return "Android"
#elseif os(PS4)
        return "PS4"
#elseif os(Cygwin)
        // TODO: `uname -r` probably works here too.
        return "Cygwin"
#elseif os(Haiku)
        return "Haiku"
#elseif os(WASI)
        return "WASI"
#else
        // On other systems at least return something.
        return "Unknown"
#endif
        
#if os(macOS) || os(Linux)
        var uts: utsname = utsname()
        if uname(&uts) == 0 {
            let versionValue = withUnsafePointer(
                to: &uts.release.0, { String(cString:  $0) })

            if !versionValue.isEmpty {
                versionString += " \(versionValue)"
            }
        }

        return versionString
#endif
    }

    var operatingSystemVersion: (major: Int, minor: Int, patch: Int) {
#if canImport(Darwin) || os(Linux) || os(FreeBSD) || os(OpenBSD) || canImport(Android)
        var uts: utsname = utsname()
        guard uname(&uts) == 0 else {
            return (major: -1, minor: 0, patch: 0)
        }
        var versionString = withUnsafePointer(
            to: &uts.release.0, { String(cString:  $0) })

        if let dashIndex = versionString.firstIndex(of: "-") {
            versionString = String(versionString[versionString.startIndex ..< dashIndex])
        }
        let version = versionString.split(separator: ".")
            .compactMap { Int($0) }
        let major = version.count >= 1 ? version[0] : -1
        let minor = version.count >= 2 ? version[1] : 0
        let patch = version.count >= 3 ? version[2] : 0
        return (major: major, minor: minor, patch: patch)
#elseif os(Windows)
        guard let osVersionInfo = self._rawOSVersion else {
            return (major: -1, minor: 0, patch: 0)
        }

        return(
            major: Int(osVersionInfo.dwMajorVersion),
            minor: Int(osVersionInfo.dwMinorVersion),
            patch: Int(osVersionInfo.dwBuildNumber)
        )
#else
        return (major: -1, minor: 0, patch: 0)
#endif
    }

    func isOperatingSystemAtLeast(_ version: (major: Int, minor: Int, patch: Int)) -> Bool {
        let (currentMajor, currentMinor, currentPatch) = operatingSystemVersion
        if currentMajor < version.major {
            return false
        }
        if currentMajor > version.major {
            return true
        }
        if currentMinor < version.minor {
            return false
        }
        if currentMinor > version.minor {
            return true
        }
        if currentPatch < version.patch {
            return false
        }
        if currentPatch > version.patch {
            return true
        }
        return true
    }
}

// MARK: - Getting Computer Information
extension _ProcessInfo {
    var processorCount: Int {
#if canImport(Darwin)
        var count: Int32 = -1
        var mib: [Int32] = [CTL_HW, HW_NCPU]
        var countSize = MemoryLayout<Int32>.size
        let status = sysctl(&mib, UInt32(mib.count), &count, &countSize, nil, 0)
        guard status == 0 else {
            return 0
        }
        return Int(count)
#elseif os(Windows)
        var siInfo = SYSTEM_INFO()
        GetSystemInfo(&siInfo)
        return Int(siInfo.dwNumberOfProcessors)
#elseif os(Linux) || os(FreeBSD) || canImport(Android)
        return Int(sysconf(Int32(_SC_NPROCESSORS_CONF)))
#else
        return 1
#endif
    }

    var activeProcessorCount: Int {
#if canImport(Darwin)
        var count: Int32 = -1
        var mib: [Int32] = [CTL_HW, HW_AVAILCPU]
        var countSize = MemoryLayout<Int32>.size
        let status = sysctl(&mib, UInt32(mib.count), &count, &countSize, nil, 0)
        guard status == 0 else {
            return 0
        }
        return Int(count)
#elseif os(Linux) || os(FreeBSD) || canImport(Android)
        #if os(Linux)
        if let fsCount = Self.fsCoreCount() {
            return fsCount
        }
        #endif
        return Int(sysconf(Int32(_SC_NPROCESSORS_ONLN)))
#elseif os(Windows)
        var sysInfo = SYSTEM_INFO()
        GetSystemInfo(&sysInfo)
        return sysInfo.dwActiveProcessorMask.nonzeroBitCount
#else
        return 0
#endif
    }
    
#if os(Linux)
    // Support for CFS quotas for cpu count as used by Docker.
    // Based on swift-nio code, https://github.com/apple/swift-nio/pull/1518
    private static let cfsQuotaURL = URL(filePath: "/sys/fs/cgroup/cpu/cpu.cfs_quota_us", directoryHint: .notDirectory)
    private static let cfsPeriodURL = URL(filePath: "/sys/fs/cgroup/cpu/cpu.cfs_period_us", directoryHint: .notDirectory)
    private static let cpuSetURL = URL(filePath: "/sys/fs/cgroup/cpuset/cpuset.cpus", directoryHint: .notDirectory)

    private static func firstLineOfFile(_ url: URL) throws -> Substring {
        let data = try Data(contentsOf: url)
        if let string = String(data: data, encoding: .utf8), let line = string.split(separator: "\n").first {
            return line
        } else {
            return ""
        }
    }

    private static func countCoreIds(cores: Substring) -> Int? {
        let ids = cores.split(separator: "-", maxSplits: 1)
        guard let first = ids.first.flatMap({ Int($0, radix: 10) }),
              let last = ids.last.flatMap({ Int($0, radix: 10) }),
              last >= first
        else {
            return nil
        }
        return 1 + last - first
    }

    private static func coreCount(cpuset cpusetURL: URL) -> Int? {
        guard let cpuset = try? firstLineOfFile(cpusetURL).split(separator: ","),
              !cpuset.isEmpty
        else { return nil }
        if let first = cpuset.first, let count = countCoreIds(cores: first) {
            return count
        } else {
            return nil
        }
    }

    private static func coreCount(quota quotaURL: URL,  period periodURL: URL) -> Int? {
        guard let quota = try? Int(firstLineOfFile(quotaURL)),
              quota > 0
        else { return nil }
        guard let period = try? Int(firstLineOfFile(periodURL)),
              period > 0
        else { return nil }

        return (quota - 1 + period) / period // always round up if fractional CPU quota requested
    }

    private static func fsCoreCount() -> Int? {
        if let quota = coreCount(quota: cfsQuotaURL, period: cfsPeriodURL) {
            return quota
        } else if let cpusetCount = coreCount(cpuset: cpuSetURL) {
            return cpusetCount
        } else {
            return nil
        }
    }
#endif

    var physicalMemory: UInt64 {
#if canImport(Darwin)
        var memory: UInt64 = 0
        var memorySize = MemoryLayout<UInt64>.size
        let name = "hw.memsize"
        return name.withCString {
            let status = sysctlbyname($0, &memory, &memorySize, nil, 0)
            if status == 0 {
                return memory
            }
            return 0
        }
#elseif os(Windows)
        var totalMemoryKB: ULONGLONG = 0
        guard GetPhysicallyInstalledSystemMemory(&totalMemoryKB) else {
            return 0
        }
        return totalMemoryKB * 1024
#elseif os(Linux) || os(FreeBSD) || canImport(Android)
        var memory = sysconf(Int32(_SC_PHYS_PAGES))
        memory *= sysconf(Int32(_SC_PAGESIZE))
        return UInt64(memory)
#else
        return 0
#endif
    }

    var systemUptime: TimeInterval {
#if canImport(Darwin)
        let (_, secondsPerTick) = _systemClockTickRate
        let time = mach_absolute_time()
        return TimeInterval(time) * secondsPerTick
#elseif os(Windows)
        return TimeInterval(GetTickCount64()) / 1000.0
#else
        var ts = timespec()
        guard clock_gettime(CLOCK_MONOTONIC, &ts) == 0 else {
            return 0
        }
        return TimeInterval(ts.tv_sec) +
            TimeInterval(ts.tv_nsec) / 1.0E9;
#endif
    }
}

extension _ProcessInfo {
    struct State {
        var processName: String?
        var arguments: [String]?
    }

    private static func _getProcessName() -> String {
        guard let processPath = CommandLine.arguments.first else {
            return ""
        }
        return processPath.lastPathComponent
    }

#if os(macOS)
    private func _getSVUID() -> UInt32? {
        var mib: (Int32, Int32, Int32, Int32) = (
            CTL_KERN,
            KERN_PROC,
            KERN_PROC_PID,
            getpid()
        )
        var kinfo: kinfo_proc = kinfo_proc()
        var klen = MemoryLayout<kinfo_proc>.size
        let ret = withUnsafeMutablePointer(to: &mib) {
            return $0.withMemoryRebound(to: Int32.self, capacity: 4) { ptr in
                return sysctl(ptr, 4, &kinfo, &klen, nil, 0)
            }
        }
        if ret != 0 {
            return nil
        }
        return kinfo.kp_eproc.e_pcred.p_svuid
    }
#endif // os(macOS)
}

#endif // !NO_PROCESS
