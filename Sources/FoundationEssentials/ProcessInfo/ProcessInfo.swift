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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _CShims
#else
package import _CShims
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(XPC)
import XPC
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
        let state: State = State(processName: _ProcessInfo._getProcessName())
        self.state = LockedState(initialState: state)
        self._hostName = LockedState(initialState: nil)
    }

    var arguments: [String] {
        return CommandLine.arguments
    }

    var environment: [String : String] {
        var results: [String : String] = [:]
        guard var environments: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> =
                _platform_shims_get_environ() else {
            return [:]
        }
        while let str = environments.pointee {
            environments = environments + 1
            let environmentString = String(cString: str)

            guard let delimiter = environmentString.firstIndex(of: "=") else {
                continue
            }

            let key = String(environmentString[environmentString.startIndex ..< delimiter])
            let value = String(environmentString[environmentString.index(after: delimiter) ..< environmentString.endIndex])
            results[key] = value
        }
        return results
    }

    var globallyUniqueString: String {
        let uuid = UUID().uuidString
        let pid = UInt64(getpid())
#if canImport(Darwin)
        let time: UInt64 = mach_absolute_time()
#else
        var ts: timespec = timespec()
        clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
        let time: UInt64 = UInt64(ts.tv_sec * 1000000000 + ts.tv_nsec)
#endif
        let timeString = String(time, radix: 16, uppercase: true)
        let padding = String(repeating: "0", count: 16 - timeString.count)
        return "\(uuid)-\(pid)-\(padding)\(timeString)"
    }

    var processIdentifier: Int32 {
        return getpid()
    }

    var processName: String {
        get {
            return state.withLock { $0.processName }
        }
        set {
            state.withLock{ $0.processName = newValue }
        }
    }

    var userName: String {
#if canImport(Darwin) || canImport(Glibc)
        // Darwin and Linux
        let (euid, _) = self._getUGIDs()
        if let upwd = getpwuid(euid),
           let uname = upwd.pointee.pw_name {
            return String(cString: uname)
        } else if let username = self.environment["USER"] {
            return username
        }
        return ""
#else
        // TODO: Windows
        return ""
#endif
    }

    var fullUserName: String {
#if canImport(Darwin) || canImport(Glibc)
        let (euid, _) = self._getUGIDs()
        if let upwd = getpwuid(euid),
           let fullname = upwd.pointee.pw_gecos {
            return String(cString: fullname)
        }
        return ""
#else
        return ""
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

    private func _getUGIDs() -> (euid: UInt32, egid: UInt32) {
        if self._canEUIDsChange {
            return Platform.getUGIDs()
        } else {
            return state.withLock {
                if let cached = $0.UGIDs {
                    return cached
                }

                $0.UGIDs = Platform.getUGIDs()
                return $0.UGIDs!
            }
        }
    }

    private var _canEUIDsChange: Bool {
#if os(macOS)
        let euid = geteuid()
        let uid = getuid()
        guard let svuid = _getSVUID() else {
            return true
        }

        return (uid == 0 || uid != euid || svuid != euid);
#else
        return true
#endif
    }
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

    var operatingSystemVersionString: String {
        // TODO: Check for `/etc/os-release` for Linux once DataIO is ready
        // https://github.com/apple/swift-foundation/issues/221
        #if os(macOS)
        var versionString = "macOS"
        #elseif os(Linux)
        var versionString = "Linux"
        #else
        var versionString = ""
        #endif
        var uts: utsname = utsname()
        if uname(&uts) == 0 {
            let versionValue = withUnsafePointer(
                to: &uts.release.0, { String(cString:  $0) })

            if !versionValue.isEmpty {
                versionString += " \(versionValue)"
            }
        }

        return versionString
    }

    var operatingSystemVersion: (major: Int, minor: Int, patch: Int) {
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
#else
        return Int(sysconf(Int32(_SC_NPROCESSORS_CONF)))
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
#else
        return Int(sysconf(Int32(_SC_NPROCESSORS_ONLN)))
#endif
    }

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
#else
        var memory = sysconf(Int32(_SC_PHYS_PAGES))
        memory *= sysconf(Int32(_SC_PAGESIZE))
        return UInt64(memory)
#endif
    }

    var systemUptime: TimeInterval {
#if canImport(Darwin)
        let (_, secondsPerTick) = _systemClockTickRate
        let time = mach_absolute_time()
        return TimeInterval(time) * secondsPerTick
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
        var processName: String
        var UGIDs: (euid: UInt32, egid: UInt32)?
    }

    private static func _getProcessName() -> String {
        guard let processPath = CommandLine.arguments.first else {
            return ""
        }

        if let lastSlash = processPath.lastIndex(of: Platform.PATH_SEPARATOR) {
            return String(processPath[
                processPath.index(after: lastSlash) ..< processPath.endIndex])
        }

        return processPath
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
