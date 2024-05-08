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

extension FileManager.SearchPathDirectory {
    #if FOUNDATION_FRAMEWORK
    static var _homeDirectory: Self {
        Self(rawValue: NSSearchPathDirectory_Private.homeDirectory.rawValue)!
    }
    #endif
}

extension FileManager.SearchPathDomainMask {
    #if FOUNDATION_FRAMEWORK
    #if os(macOS)
    static var _sharedUserDomainMask: Self {
        Self(rawValue: NSSearchPathDomainMask_Private.sharedUserDomainMask.rawValue)
    }
    #endif
    
    static var _partitionedSystemDomainMask: Self {
        Self(rawValue: NSSearchPathDomainMask_Private.partitionedSystemDomainMask.rawValue)
    }
    
    static var _appCryptexDomainMask: Self {
        Self(rawValue: NSSearchPathDomainMask_Private.appCryptexDomainMask.rawValue)
    }
    
    static var _osCryptexDomainMask: Self {
        Self(rawValue: NSSearchPathDomainMask_Private.osCryptexDomainMask.rawValue)
    }
    #endif
    
    fileprivate var firstMask: Self? {
        guard !self.isEmpty else { return nil }
        return Self(rawValue: 1 << self.rawValue.trailingZeroBitCount)
    }
    
    fileprivate static var valid: Self {
        #if FOUNDATION_FRAMEWORK
        [.userDomainMask, .localDomainMask, .networkDomainMask, .systemDomainMask, ._appCryptexDomainMask, ._osCryptexDomainMask]
        #else
        [.userDomainMask, .localDomainMask, .networkDomainMask, .systemDomainMask]
        #endif
    }
}

func _SearchPathURLs(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, expandTilde: Bool) -> some Sequence<URL> {
    #if canImport(Darwin)
    let basic = _DarwinSearchPathsSequence(directory: directory, domainMask: domain.intersection(.valid)).lazy.map {
        if expandTilde {
            return URL(filePath: $0.expandingTildeInPath, directoryHint: .isDirectory)
        } else {
            return URL(filePath: $0, directoryHint: .isDirectory)
        }
    }
    
    #if os(macOS) && FOUNDATION_FRAMEWORK
    // NSSharedUserDomainMask is basically just a wrapper around NSUserDomainMask.
    let compatibleSharedUserDomainMask = domain != .allDomainsMask && (domain.rawValue & 16) != 0
    if domain.contains(._sharedUserDomainMask) || compatibleSharedUserDomainMask {
        var result = Array(basic)
        for path in _DarwinSearchPathsSequence(directory: directory, domainMask: .userDomainMask) {
            let expandedURL = URL(filePath: expandTilde ? path.replacingTildeWithRealHomeDirectory : path, directoryHint: .isDirectory)
            // Avoid duplicates, which would occur with (NSUserDomainMask | NSSharedUserDomainMask) in non-sandboxed apps.
            if !result.contains(expandedURL) {
                // Insert this path after NSUserDomainMask and before any of the more general paths.
                let insertionIndex = domain.contains(.userDomainMask) ? 1 : 0
                result.insert(expandedURL, at: insertionIndex)
            }
        }
        return result
    }
    #endif
    return Array(basic)
    #else
    var result = Set<URL>()
    var domain = domain.intersection(.valid)
    while let currentDomain = domain.firstMask {
        domain.remove(currentDomain)
        #if os(Windows)
        let url = _WindowsSearchPathURL(for: directory, in: currentDomain)
        #else
        let url = _XDGSearchPathURL(for: directory, in: currentDomain)
        #endif
        if let url {
            result.insert(url)
        }
    }
    return result
    #endif
}
