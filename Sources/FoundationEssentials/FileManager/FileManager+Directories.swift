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
#elseif canImport(Android)
@preconcurrency import Android
import unistd
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif os(Windows)
import CRT
import WinSDK
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

internal import _FoundationCShims

#if FOUNDATION_FRAMEWORK
func _LogSpecialFolderRecreation(_ fileManager: FileManager, _ path: String) {
    if UserDefaults.standard.bool(forKey: "NSLogSpecialFolderRecreation") && !fileManager.fileExists(atPath: path) {
        Logger().info("*** Application: \(Bundle.main.bundleIdentifier ?? "(null)") just recreated special folder: \(path)")
    }
}
#endif

extension _FileManagerImpl {
    var homeDirectoryForCurrentUser: URL {
        URL(filePath: String.homeDirectoryPath(), directoryHint: .isDirectory)
    }
    
    func homeDirectory(forUser userName: String?) -> URL? {
        guard let userName else {
            return homeDirectoryForCurrentUser
        }
        guard let path = String.homeDirectoryPath(forUser: userName) else {
            return nil
        }
        return URL(filePath: path, directoryHint: .isDirectory)
    }
    
    var temporaryDirectory: URL {
        URL(filePath: String.temporaryDirectoryPath, directoryHint: .isDirectory)
    }
    
    func url(
        for directory: FileManager.SearchPathDirectory,
        in domain: FileManager.SearchPathDomainMask,
        appropriateFor url: URL?,
        create shouldCreate: Bool
    ) throws -> URL {
        #if FOUNDATION_FRAMEWORK
        // TODO: Support correct trash/replacement locations in swift-foundation
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
        #endif
        
        let urls = Array(_SearchPathURLs(for: directory, in: domain, expandTilde: true))
        #if FOUNDATION_FRAMEWORK
        let url = domain == ._partitionedSystemDomainMask ? urls.last : urls.first
        #else
        let url = urls.first
        #endif
        
        guard let url else {
            throw CocoaError(.fileReadUnknown)
        }
        
        if shouldCreate {
            #if FOUNDATION_FRAMEWORK
            _LogSpecialFolderRecreation(fileManager, url.path)
            #endif
            var isUserDomain = domain == .userDomainMask
            #if os(macOS) && FOUNDATION_FRAMEWORK
            isUserDomain = isUserDomain || domain == ._sharedUserDomainMask
            #endif
            var attrDictionary: [FileAttributeKey : Any] = [:]
            if isUserDomain {
                attrDictionary[.posixPermissions] = 0o700
            } else {
                #if FOUNDATION_FRAMEWORK
                if domain == ._partitionedSystemDomainMask {
                    attrDictionary[.posixPermissions] = 0o755
                    attrDictionary[.ownerAccountID] = 0 // root
                    attrDictionary[.groupOwnerAccountID] = 80 // admin
                }
                #endif
            }
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: attrDictionary)
        }
        return url
    }
    
    func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        Array(_SearchPathURLs(for: directory, in: domainMask, expandTilde: true))
    }
    
    #if FOUNDATION_FRAMEWORK
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
#if os(Windows)
        let iterator = _Win32DirectoryContentsSequence(path: path, appendSlashForDirectory: false).makeIterator()
#else
        let iterator = _POSIXDirectoryContentsSequence(path: path, appendSlashForDirectory: false).makeIterator()
#endif
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
#if os(Windows)
        try path.withNTPathRepresentation {
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            guard GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes) else {
                throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
            }
        }

        var results: [String] = []
        for item in _Win32DirectoryContentsSequence(path: path, appendSlashForDirectory: true) {
            results.append(item.fileName)
            if item.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY &&
                item.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != FILE_ATTRIBUTE_REPARSE_POINT {

                var pwszSubPath: PWSTR? = nil
                let hr = PathAllocCombine(path, item.fileName, PATHCCH_ALLOW_LONG_PATHS, &pwszSubPath)
                guard hr == S_OK else {
                    throw CocoaError.errorWithFilePath(path, win32: WIN32_FROM_HRESULT(hr), reading: true)
                }
                defer { LocalFree(pwszSubPath) }

                results.append(contentsOf: try subpathsOfDirectory(atPath: String(decodingCString: pwszSubPath!, as: UTF16.self)).map {
                    var pwszFullPath: PWSTR? = nil
                    _ = PathAllocCombine(item.fileName, $0, PATHCCH_ALLOW_LONG_PATHS, &pwszFullPath)
                    defer { LocalFree(pwszFullPath) }
                    return String(decodingCString: pwszFullPath!, as: UTF16.self).standardizingPath.replacing("\\", with: "/")
                 })
            }
        }
        return results
#elseif os(OpenBSD)
        throw CocoaError.errorWithFilePath(.featureUnsupported, path)
#else
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
#endif
    }

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

    func createDirectory(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey : Any]? = nil
    ) throws {
#if os(Windows)
        var saAttributes: SECURITY_ATTRIBUTES =
            SECURITY_ATTRIBUTES(nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
                                lpSecurityDescriptor: nil,
                                bInheritHandle: false)
        // `CreateDirectoryW` does not create intermediate directories, so we need to handle that manually.  
        // Note: `SHCreateDirectoryExW` seems to have issues with long paths.
        if createIntermediates {
            // Create intermediate directories recursively
            func _createDirectoryRecursively(at directoryPath: String) throws {
                try directoryPath.withNTPathRepresentation { pwszPath in
                    // Create this directory
                    guard CreateDirectoryW(pwszPath, &saAttributes) else {
                        let lastError = GetLastError()
                        if lastError == ERROR_ALREADY_EXISTS {
                            var isDir: Bool = false
                            if fileExists(atPath: directoryPath, isDirectory: &isDir), isDir {
                                return // Directory now exists, success
                            }
                        } else if lastError == ERROR_PATH_NOT_FOUND {
                            let parentPath = directoryPath.deletingLastPathComponent()
                            if !parentPath.isEmpty && parentPath != directoryPath {
                                // Recursively create parent directory
                                try _createDirectoryRecursively(at: parentPath)
                                // Now try creating this one again.
                                guard CreateDirectoryW(pwszPath, &saAttributes) else {
                                    let lastError = GetLastError()
                                    if lastError == ERROR_ALREADY_EXISTS {
                                        var isDir: Bool = false
                                        if fileExists(atPath: directoryPath, isDirectory: &isDir), isDir {
                                            return // Directory now exists, success
                                        }
                                    }
                                    throw CocoaError.errorWithFilePath(directoryPath, win32: lastError, reading: false)
                                }
                                return
                            }
                        }
                        throw CocoaError.errorWithFilePath(directoryPath, win32: lastError, reading: false)
                    }
                }
            }
            
            try _createDirectoryRecursively(at: path)
            if let attributes {
                try? fileManager.setAttributes(attributes, ofItemAtPath: path)
            }
        } else {
            try path.withNTPathRepresentation { pwszPath in
                guard CreateDirectoryW(pwszPath, &saAttributes) else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: false)
                }
            }
            if let attributes {
                try? fileManager.setAttributes(attributes, ofItemAtPath: path)
            }
        }
#else
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
#endif
    }
    
#if FOUNDATION_FRAMEWORK
    func getRelationship(
        _ outRelationship: UnsafeMutablePointer<FileManager.URLRelationship>,
        ofDirectoryAt directoryURL: URL,
        toItemAt otherURL: URL
    ) throws {
        // Get url's resource identifier, volume identifier, and make sure it is a directory
        let dirValues = try directoryURL.resourceValues(forKeys: [.fileResourceIdentifierKey, .volumeIdentifierKey, .isDirectoryKey])
        
        guard let isDirectory = dirValues.isDirectory, isDirectory else {
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
#if os(Windows)
        return (try? path.withNTPathRepresentation {
            // It seems setting CWD with the long name prefix causes issues with calls to GetFullPathNameW, path which are just '\'
            // end up coming back a '\\' instead of 'C:\'.  There is some gih ub comments suggesting the prefix does not work with
            // SetCurrentDirectroy either (https://github.com/MicrosoftDocs/feedback/issues/1441#issuecomment-506574206)
            String(decodingCString: $0, as: UTF16.self).removingNTPathPrefix().withCString(encodedAs: UTF16.self) { pwszStripped in
                SetCurrentDirectoryW(pwszStripped)
            }
        }) ?? false
#else
        fileManager.withFileSystemRepresentation(for: path) { rep in
            guard let rep else { return false }
            return chdir(rep) == 0
        }
#endif
    }
    
    var currentDirectoryPath: String? {
#if os(Windows)
        // Make an initial call to GetCurrentDirectoryW to get a buffer size estimate.
        // This is solely to minimize the number of allocations and number of bytes allocated versus starting with a hardcoded value like MAX_PATH.
        // We should NOT early-return if this returns 0, in order to avoid TOCTOU issues.
        let dwSize = GetCurrentDirectoryW(0, nil)
        return try? FillNullTerminatedWideStringBuffer(initialSize: dwSize >= 0 ? dwSize : DWORD(MAX_PATH), maxSize: DWORD(Int16.max)) {
            GetCurrentDirectoryW(DWORD($0.count), $0.baseAddress)
        }
#else
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { buffer in
            guard getcwd(buffer.baseAddress!, FileManager.MAX_PATH_SIZE) != nil else {
                return nil
            }
            return fileManager.string(withFileSystemRepresentation: buffer.baseAddress!, length: strlen(buffer.baseAddress!))
        }
#endif
    }
}
