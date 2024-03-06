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

#if FOUNDATION_FRAMEWORK
internal import containermanager
internal import _ForSwiftFoundation
internal import os
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

internal import _CShims

#if FOUNDATION_FRAMEWORK
var _shouldLog: Bool = {
    UserDefaults.standard.bool(forKey: "NSLogSpecialFolderRecreation")
}()
func _LogSpecialFolderRecreation(_ fileManager: FileManager, _ path: String) {
    if _shouldLog && !fileManager.fileExists(atPath: path) {
        Logger().info("*** Application: \(Bundle.main.bundleIdentifier ?? "(null)") just recreated special folder: \(path)")
    }
}
#endif

extension _FileManagerImpl {
    var homeDirectoryForCurrentUser: URL {
        URL(filePath: String.homeDirectoryPath(), directoryHint: .isDirectory)
    }
    
    func homeDirectory(forUser userName: String?) -> URL? {
        URL(filePath:  String.homeDirectoryPath(forUser: userName), directoryHint: .isDirectory)
    }
    
    var temporaryDirectory: URL {
        URL(filePath: String.temporaryDirectoryPath, directoryHint: .isDirectory)
    }
    
    #if FOUNDATION_FRAMEWORK
    func url(
        for directory: FileManager.SearchPathDirectory,
        in domain: FileManager.SearchPathDomainMask,
        appropriateFor url: URL?,
        create shouldCreate: Bool
    ) throws -> URL {
        #if os(macOS) || os(iOS)
        if let url, directory == .trashDirectory {
            return try fileManager._URLForTrashingItem(at: url, create: shouldCreate)
        }
        #endif
        if let url, domain == .userDomainMask, directory == .itemReplacementDirectory {
            // The only place we need to do this is for certain operations, namely the replacing item API.
            return try fileManager._URLForReplacingItem(at: url)
        }
        var domain = domain
        if domain == .systemDomainMask {
            domain = ._partitionedSystemDomainMask
        }
        let paths = Array(_SearchPaths(for: directory, in: domain, expandTilde: true))
        guard let path = domain == ._partitionedSystemDomainMask ? paths.last : paths.first else {
            throw CocoaError(.fileReadUnknown)
        }
        
        if shouldCreate {
            #if FOUNDATION_FRAMEWORK
            _LogSpecialFolderRecreation(fileManager, path)
            #endif
            var isUserDomain = domain == .userDomainMask
            #if os(macOS)
            isUserDomain = isUserDomain || domain == ._sharedUserDomainMask
            #endif
            var attrDictionary: [FileAttributeKey : Any] = [:]
            if isUserDomain {
                attrDictionary[.posixPermissions] = 0o700
            } else if domain == ._partitionedSystemDomainMask {
                attrDictionary[.posixPermissions] = 0o755
                attrDictionary[.ownerAccountID] = 0 // root
                attrDictionary[.groupOwnerAccountID] = 80 // admin
            }
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: attrDictionary)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    
    func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        _SearchPaths(for: directory, in: domainMask, expandTilde: true).map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }
    
    func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? {
        groupIdentifier.withCString {
            guard let path = container_create_or_lookup_app_group_path_by_app_group_identifier($0, nil)  else {
                return nil
            }
            
            defer { path.deallocate() }
            return URL(fileURLWithFileSystemRepresentation: path, isDirectory: true, relativeTo: nil)
        }
    }
#endif
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        #if os(macOS)
        // CFURLEnumerator/CarbonCore does not operate on /dev paths
        if !path.standardizingPath.starts(with: "/dev") {
            guard fileManager.fileExists(atPath: path) else {
                throw CocoaError.errorWithFilePath(path, osStatus: -43 /*fnfErr*/, reading: true, variant: "Folder")
            }
            
            #if FOUNDATION_FRAMEWORK
            // Use CFURLEnumerator in Foundation framework, otherwise fallback to POSIX sequence below
            var err: NSError?
            guard let result = _NSDirectoryContentsFromCFURLEnumeratorError(URL(fileURLWithPath: path, isDirectory: true), nil, 0, true, &err) else {
                throw err!
            }
            return result
            #endif
        }
        #endif
        var result: [String] = []
        let iterator = _POSIXDirectoryContentsSequence(path: path, appendSlashForDirectory: false).makeIterator()
        if let error = iterator.error {
            throw error
        } else {
            while let item = iterator.next() {
                result.append(item.fileName)
            }
        }
        return result
    }
    
    func subpathsOfDirectory(atPath path: String) throws -> [String] {
        return try path.withFileSystemRepresentation { fileSystemRep in
            guard let fileSystemRep else {
                throw CocoaError.errorWithFilePath(.fileNoSuchFile, path)
            }
            
            let subpaths = _FTSSequence(fileSystemRep, FTS_PHYSICAL | FTS_NOCHDIR | FTS_NOSTAT).subpaths
            var realFirstPath: String?
            
            var results: [String] = []
            for item in subpaths {
                var subpath: String
                switch item {
                case .error(let errNum, let p):
                    throw CocoaError.errorWithFilePath(p, errno: errNum, reading: true)
                case .entry(let path):
                    subpath = path
                }
                
                guard let realFirstPath else {
                    realFirstPath = subpath
                    continue
                }
                
                let trueSubpath = subpath.trimmingPrefix(realFirstPath)
                if trueSubpath.first == "/" {
                    results.append(String(trueSubpath.dropFirst()))
                } else if !trueSubpath.isEmpty {
                    results.append(String(trueSubpath))
                }
            }
            return results
        }
    }
    
    #if FOUNDATION_FRAMEWORK
    func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey : Any]? = nil
    ) throws {
        guard url.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileWriteUnsupportedScheme, url)
        }
        
        let path = url.path
        guard !path.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, url)
        }
        
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
    #endif
    
    func createDirectory(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey : Any]? = nil
    ) throws {
        try fileManager.withFileSystemRepresentation(for: path) { pathPtr in
            guard let pathPtr else {
                throw CocoaError.errorWithFilePath(.fileWriteUnknown, path)
            }
            
            guard createIntermediates else {
                guard mkdir(pathPtr, 0o777) == 0 else {
                    throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                }
                if let attributes {
                    try? fileManager.setAttributes(attributes, ofItemAtPath: path)
                }
                return
            }
            
            #if FOUNDATION_FRAMEWORK
            var firstDirectoryPtr: UnsafePointer<CChar>?
            defer { firstDirectoryPtr?.deallocate() }
            let result = _mkpath_np(pathPtr, S_IRWXU | S_IRWXG | S_IRWXO, &firstDirectoryPtr)
            
            guard result == 0 else {
                guard result != EEXIST else { return }
                var errNum = result
                var errPath = path
                if result == ENOTDIR {
                    // _mkpath_np reports ENOTDIR when any component in the path is a regular file. We need to do two things to ensure binary compatibility: 1) find that file -- we have to report it in the error, and 2) special-case the last component. For whatever reason, we've always reported EEXIST for this case. This requires some extra stat'ing.
                    var currentDirectory = path
                    var isLastComponent = true
                    // This shouldn't happen unless there are file system races going on, but stop iterating when we reach "/".
                    while currentDirectory.count > 1 {
                        if fileManager.fileExists(atPath: currentDirectory) {
                            errPath = currentDirectory
                            if isLastComponent {
                                errNum = EEXIST
                            }
                            break
                        }
                        currentDirectory = currentDirectory.deletingLastPathComponent()
                        isLastComponent = false
                    }
                }
                throw CocoaError.errorWithFilePath(errPath, errno: errNum, reading: false)
            }
            
            guard let attributes else {
                return // Nothing left to do
            }
            
            // The directory was successfully created. To keep binary compatibility, we need to post-process the newly created directories and set attributes.
            // We're relying on the knowledge that _mkpath_np does not change any of the parent path components of firstDirectory. Otherwise, I think we'd have to canonicalize paths or check for IDs, which would probably require more file system calls than is worthwhile.
            var currentDirectory = firstDirectoryPtr.flatMap(String.init(cString:)) ?? path
            
            // Start with the first newly created directory.
            try? fileManager.setAttributes(attributes, ofItemAtPath: currentDirectory)// Not returning error to preserve binary compatibility.
            
            // Now append each subsequent path component.
            let fullComponents = path.pathComponents
            let currentComponents = currentDirectory.pathComponents
            for component in fullComponents[currentComponents.count...] {
                currentDirectory = currentDirectory.appendingPathComponent(component)
                try? fileManager.setAttributes(attributes, ofItemAtPath: currentDirectory) // Not returning error to preserve binary compatibility.
            }
            #else
            func _create(path: String, leafFile: Bool = true) throws {
                var isDir = false
                guard !fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
                    if !isDir && leafFile {
                        throw CocoaError.errorWithFilePath(path, errno: EEXIST, reading: false)
                    }
                    return
                }
                let parent = path.deletingLastPathComponent()
                if !parent.isEmpty {
                    try _create(path: parent, leafFile: false)
                }
                try fileManager.withFileSystemRepresentation(for: path) { pathFsRep in
                    guard let pathFsRep else {
                        throw CocoaError.errorWithFilePath(.fileWriteInvalidFileName, path)
                    }
                    guard mkdir(pathFsRep, 0o777) == 0 else {
                        let posixErrno = errno
                        if posixErrno == EEXIST && fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir {
                            // Continue; if there is an existing file and it is a directory, that is still a success.
                            // There can be an existing file if another thread or process concurrently creates the
                            // same file.
                            return
                        } else {
                            throw CocoaError.errorWithFilePath(path, errno: posixErrno, reading: false)
                        }
                    }
                    if let attr = attributes {
                        try? fileManager.setAttributes(attr, ofItemAtPath: path)
                    }
                }
            }
            try _create(path: path)
            #endif
        }
    }
    
    #if FOUNDATION_FRAMEWORK
    func getRelationship(
        _ outRelationship: UnsafeMutablePointer<FileManager.URLRelationship>,
        ofDirectoryAt directoryURL: URL,
        toItemAt otherURL: URL
    ) throws {
        // Get url's resource identifier, volume identifier, and make sure it is a directory
        let dirValues = try directoryURL.resourceValues(forKeys: [.fileResourceIdentifierKey, .volumeIdentifierKey, .isDirectoryKey])
        
        guard dirValues.isDirectory! else {
            outRelationship.pointee = .other
            return
        }
        
        // Get other's resource identifier and make sure it is not the same resource as otherURL
        let otherValues = try otherURL.resourceValues(forKeys: [.fileIdentifierKey, .fileResourceIdentifierKey, .volumeIdentifierKey])
        guard !otherValues.fileResourceIdentifier!.isEqual(dirValues.fileResourceIdentifier!) else {
            outRelationship.pointee = .same
            return
        }
        
        guard otherValues.volumeIdentifier!.isEqual(dirValues.volumeIdentifier!) else {
            outRelationship.pointee = .other
            return
        }
        
        // Start looking through the parent chain up to the volume root for a parent that is equal to 'url'. Stop when the current URL reaches the volume root
        var currentURL = otherURL
        while try !currentURL.resourceValues(forKeys: [.isVolumeKey]).isVolume! {
            // Get url's parentURL
            let parentURL = try currentURL.resourceValues(forKeys: [.parentDirectoryURLKey]).parentDirectory!
            
            let parentResourceID = try parentURL.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier!
            
            if parentResourceID.isEqual(dirValues.fileResourceIdentifier!) {
                outRelationship.pointee = .contains
                return
            }
            
            currentURL = parentURL
        }
        
        outRelationship.pointee = .other
        return
    }
    
    func getRelationship(
        _ outRelationship: UnsafeMutablePointer<FileManager.URLRelationship>,
        of directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask,
        toItemAt url: URL
    ) throws {
        // Figure out the standard directory, then call the other API
        let directoryURL = try fileManager.url(
            for: directory,
            in: domainMask,
            appropriateFor: domainMask.isEmpty ? url : nil,
            create: false)
        return try fileManager.getRelationship(
            outRelationship,
            ofDirectoryAt: directoryURL,
            toItemAt: url)
    }
#endif
    
    func changeCurrentDirectoryPath(_ path: String) -> Bool {
        fileManager.withFileSystemRepresentation(for: path) { rep in
            guard let rep else { return false }
#if os(Windows)
            return SetCurrentDirectoryW(rep)
#else
            return chdir(rep) == 0
#endif
        }
    }
    
    var currentDirectoryPath: String? {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { buffer in
#if !os(Windows)
            guard getcwd(buffer.baseAddress!, FileManager.MAX_PATH_SIZE) != nil else {
                return nil
            }
#else
            guard GetCurrentDirectoryW(FileManager.MAX_PATH_SIZE, buffer.baseAddress!) >= 0 else {
                return nil
            }
#endif
            
            return fileManager.string(withFileSystemRepresentation: buffer.baseAddress!, length: strlen(buffer.baseAddress!))
        }
    }
}
