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

#if FOUNDATION_FRAMEWORK && !NO_PROCESS
@_implementationOnly import _ForSwiftFoundation
@_implementationOnly import MachO_Private.dyld
@_implementationOnly import CoreFoundation_Private

@objc(_NSSwiftProcessInfo)
internal final class _NSSwiftProcessInfo: ProcessInfo {

    private static let _shared: _NSSwiftProcessInfo = _NSSwiftProcessInfo()

    internal var _state: LockedState<State>
    private let _processInfo: _ProcessInfo

    override static var processInfo: ProcessInfo {
        return _shared
    }

#if canImport(notify)
    internal lazy var _thermalNotificationRegisted: Bool = {
        _registerThermalStateNotification()
        return true
    }()

    internal lazy var _powerStateNotificationRegisted: Bool = {
        _registerPowerStateNotification()
        return true
    }()
#endif


    override init() {
        _state = .init(initialState: .init())
        _processInfo = _ProcessInfo.processInfo
        super.init()
    }
}

// MARK: - Accessing Process Information
extension _NSSwiftProcessInfo {
    override var arguments: [String] { _processInfo.arguments }
    override var environment: [String : String] { _processInfo.environment }
    override var globallyUniqueString: String { _processInfo.globallyUniqueString }
    override var processIdentifier: Int32 { _processInfo.processIdentifier }
    override var processName: String {
        get { _processInfo.processName }
        set { _processInfo.processName = newValue }
    }

    override var isMacCatalystApp: Bool {
#if (os(macOS) || targetEnvironment(macCatalyst)) && !(FOUNDATION_FRAMEWORK && !canImport(FoundationICU))
        return dyld_get_active_platform() == PLATFORM_MACCATALYST ||
            dyld_get_active_platform() == PLATFORM_IOS
#else
        return false
#endif
    }

    override var isiOSAppOnMac: Bool {
#if os(macOS)
        return dyld_get_active_platform() == PLATFORM_IOS
#else
        return false
#endif
    }
}

// MARK: - Accessing User Information
extension _NSSwiftProcessInfo {
#if os(macOS)
    override var userName: String { _processInfo.userName }
    override var fullUserName: String { _processInfo.fullUserName }
#endif
}

// MARK: - Getting Computer Information
extension _NSSwiftProcessInfo {
    override var processorCount: Int { _processInfo.processorCount }
    override var activeProcessorCount: Int { _processInfo.activeProcessorCount }
    override var physicalMemory: UInt64 { _processInfo.physicalMemory }
    override var systemUptime: TimeInterval { _processInfo.systemUptime }
}

// MARK: - Getting Host Information
extension _NSSwiftProcessInfo {
    override var hostName: String { _processInfo.hostName }

    override var operatingSystemVersionString: String {
        // TODO: Move to Swift once Plist is ready
        return CFCopySystemVersionString()
            .takeRetainedValue() as String
    }

    override var operatingSystemVersion: OperatingSystemVersion {
        var result = OperatingSystemVersion(majorVersion: -1, minorVersion: 0, patchVersion: 0)
        var resolvedProductVersionKey = "ProductVersion"
        #if os(macOS)
        // If we're on a Mac but running an iOS app, use the `iOSSupportVersion` instead
        if dyld_get_active_platform() == PLATFORM_IOS {
            resolvedProductVersionKey = "iOSSupportVersion"
        }
        #endif
        let productVersion = _CFCopySystemVersionDictionaryValue(resolvedProductVersionKey as CFString)
        guard let versionString = productVersion?.takeRetainedValue() as? String else {
            return result
        }
        let components = versionString.split(separator: ".")
        guard !components.isEmpty, let major = Int(components[0]) else {
            return result
        }
        result.majorVersion = major

        guard components.count > 1, let minor = Int(components[1]) else {
            return result
        }
        result.minorVersion = minor

        guard components.count > 2, let patch = Int(components[2]) else {
            return result
        }
        result.patchVersion = patch

        return result
    }

    override func isOperatingSystemAtLeast(_ version: OperatingSystemVersion) -> Bool {
        let current = operatingSystemVersion
        return current.isVersionAtLeast(version)
    }
}

internal extension OperatingSystemVersion {
    func isVersionAtLeast(_ version: OperatingSystemVersion) -> Bool {
        if self.majorVersion < version.majorVersion {
            return false
        }
        if self.majorVersion > version.majorVersion {
            return true
        }
        if self.minorVersion < version.minorVersion {
            return false
        }
        if self.minorVersion > version.minorVersion {
            return true
        }
        if self.patchVersion < version.patchVersion {
            return false
        }
        if self.patchVersion > version.patchVersion {
            return true
        }
        return true
    }
}

#endif // FOUNDATION_FRAMEWORK && !NO_PROCESS
