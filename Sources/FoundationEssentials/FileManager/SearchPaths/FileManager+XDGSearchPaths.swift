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

#if !canImport(Darwin) && !os(Windows)

private func _xdgHomeURL() -> URL {
    if let homeEnvValue = ProcessInfo.processInfo.environment["HOME"], !homeEnvValue.isEmpty {
        return URL(filePath: homeEnvValue, directoryHint: .isDirectory)
    } else {
        return __xdgHomeURL
    }
}

private let __xdgHomeURL: URL = {
    if let data = try? Data(contentsOf: URL(filePath: "/etc/default/useradd", directoryHint: .notDirectory)) {
        let contents = String(decoding: data, as: UTF8.self)
        for line in contents.split(separator: "\n") {
            if line.starts(with: "HOME="), let equalsIndex = line.firstIndex(of: "=") {
                let path = String(line[line.index(after: equalsIndex)...])
                return URL(filePath: path, directoryHint: .isDirectory)
            }
        }
    }
    return URL(filePath: "/home", directoryHint: .isDirectory)
}()

/// A single base directory relative to which user-specific data files should be written. This directory is defined by the environment variable $XDG_DATA_HOME.
private func _xdgDataHomeURL() -> URL {
    // $XDG_DATA_HOME defines the base directory relative to which user specific data files should be stored. If $XDG_DATA_HOME is either not set or empty, a default equal to $HOME/.local/share should be used.
    if let envValue = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], envValue.unicodeScalars.first == "/" {
        return URL(filePath: envValue, directoryHint: .isDirectory)
    }
    return _xdgHomeURL().appending(path: ".local/share", directoryHint: .isDirectory)
}

/// A single base directory relative to which user-specific non-essential (cached) data should be written. This directory is defined by the environment variable $XDG_CACHE_HOME.
private func _xdgCacheURL() -> URL {
    // $XDG_CACHE_HOME defines the base directory relative to which user specific non-essential data files should be stored. If $XDG_CACHE_HOME is either not set or empty, a default equal to $HOME/.cache should be used.
    if let envValue = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"], envValue.unicodeScalars.first == "/" {
        return URL(filePath: envValue, directoryHint: .isDirectory)
    }
    return _xdgHomeURL().appending(component: ".cache", directoryHint: .isDirectory)
}

/// A single base directory relative to which user-specific configuration files should be written. This directory is defined by the environment variable $XDG_CONFIG_HOME.
private func _xdgConfigHomeURL() -> URL {
    // $XDG_CONFIG_HOME defines the base directory relative to which user specific configuration files should be stored. If $XDG_CONFIG_HOME is either not set or empty, a default equal to $HOME/.config should be used.
    if let envValue = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], envValue.unicodeScalars.first == "/" {
        return URL(filePath: envValue, directoryHint: .isDirectory)
    }
    return _xdgHomeURL().appending(component: ".config", directoryHint: .isDirectory)
}

/// A set of preference ordered base directories relative to which configuration files should be searched. This set of directories is defined by the environment variable $XDG_CONFIG_DIRS.
private func _xdgConfigURLs() -> [URL] {
    // $XDG_CONFIG_DIRS defines the preference-ordered set of base directories to search for configuration files in addition to the $XDG_CONFIG_HOME base directory. The directories in $XDG_CONFIG_DIRS should be separated with a colon ':'.
    // If $XDG_CONFIG_DIRS is either not set or empty, a value equal to /etc/xdg should be used.
    if let envValue = ProcessInfo.processInfo.environment["XDG_CONFIG_DIRS"], !envValue.isEmpty {
        let directories = envValue.split(separator: ":")
        if !directories.isEmpty {
            return directories.map { URL(filePath: String($0), directoryHint: .isDirectory) }
        }
    }
    return [URL(filePath: "/etc/xdg", directoryHint: .isDirectory)]
}

private enum _XDGUserDirectory: String {
    case desktop = "DESKTOP"
    case download = "DOWNLOAD"
    case publicShare = "PUBLICSHARE"
    case documents = "DOCUMENTS"
    case music = "MUSIC"
    case pictures = "PICTURES"
    case videos = "VIDEOS"
    
    var url: URL {
        return url(userConfiguration: _XDGUserDirectory.configuredDirectoryURLs, osDefaultConfiguration: _XDGUserDirectory.osDefaultDirectoryURLs)
    }
    
    func url(userConfiguration: [_XDGUserDirectory: URL], osDefaultConfiguration: [_XDGUserDirectory: URL]) -> URL {
        if let url = userConfiguration[self] {
            return url
        } else if let url = osDefaultConfiguration[self] {
            return url
        } else {
            return self.defaultValue
        }
    }
    
    var defaultValue: URL {
        let component = switch self {
            case .desktop: "Desktop"
            case .download: "Downloads"
            case .publicShare: "Public"
            case .documents: "Documents"
            case .music: "Music"
            case .pictures: "Pictures"
            case .videos: "Videos"
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(component: component)
    }
    
    private static func parseConfigFile(_ url: URL) -> [_XDGUserDirectory: URL]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let configuration = String(decoding: data, as: UTF8.self)
        
        var entries: [_XDGUserDirectory: URL] = [:]
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        for line in configuration.split(separator: "\n") {
            if let equalsIdx = line.firstIndex(of: "=") {
                var variable = String(line[..<equalsIdx])._trimmingWhitespace()
                
                let prefix = "XDG_"
                let suffix = "_DIR"
                if variable.hasPrefix(prefix) && variable.hasSuffix(suffix) {
                    let endOfPrefix = variable.unicodeScalars.index(variable.startIndex, offsetBy: prefix.unicodeScalars.count)
                    let startOfSuffix = variable.unicodeScalars.index(variable.endIndex, offsetBy: -suffix.unicodeScalars.count)
                    
                    variable = String(variable[endOfPrefix ..< startOfSuffix])
                }
                
                guard let directory = _XDGUserDirectory(rawValue: variable) else {
                    continue
                }
                
                let path = String(line[line.unicodeScalars.index(after: equalsIdx)...])._trimmingWhitespace()
                if !path.isEmpty {
                    entries[directory] = URL(filePath: path, directoryHint: .isDirectory, relativeTo: home)
                }
            } else {
                return nil // Incorrect syntax.
            }
        }
        
        return entries
    }
    
    private static let configuredDirectoryURLs: [_XDGUserDirectory: URL] = {
        parseConfigFile(_xdgConfigHomeURL().appending(component: "user-dirs.dirs")) ?? [:]
    }()
    
    private static let osDefaultDirectoryURLs: [_XDGUserDirectory: URL] = {
        for directory in _xdgConfigURLs() {
            let configurationFile = directory.appending(component: "user-dirs.defaults")
            
            if let result = parseConfigFile(configurationFile) {
                return result
            }
        }
        
        return [:]
    }()
}

func _XDGSearchPathURL(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask) -> URL? {
    return switch (directory, domain) {
    case (.autosavedInformationDirectory, _):
        _xdgDataHomeURL().appending(component: "Autosave Information", directoryHint: .isDirectory)
        
    case (.desktopDirectory, .userDomainMask):
        _XDGUserDirectory.desktop.url
        
    case (.documentDirectory, .userDomainMask):
        _XDGUserDirectory.documents.url
        
    case (.cachesDirectory, .userDomainMask):
        _xdgCacheURL()
        
    case (.applicationSupportDirectory, .userDomainMask):
        _xdgDataHomeURL()
        
    case (.downloadsDirectory, .userDomainMask):
        _XDGUserDirectory.download.url
        
    case (.userDirectory, .localDomainMask):
        _xdgHomeURL()
        
    case (.moviesDirectory, .userDomainMask):
        _XDGUserDirectory.videos.url
        
    case (.musicDirectory, .userDomainMask):
        _XDGUserDirectory.music.url
        
    case (.picturesDirectory, .userDomainMask):
        _XDGUserDirectory.pictures.url
        
    case (.sharedPublicDirectory, .userDomainMask):
        _XDGUserDirectory.publicShare.url
        
    case (.trashDirectory, .localDomainMask), (.trashDirectory, .userDomainMask):
        FileManager.default.homeDirectoryForCurrentUser.appending(component: ".Trash", directoryHint: .isDirectory)
        
    default: nil
    }
}

#endif
