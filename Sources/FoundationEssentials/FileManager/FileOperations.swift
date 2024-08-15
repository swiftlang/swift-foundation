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

#if canImport(Darwin)
import Darwin
#elseif os(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import CRT
import WinSDK
#endif

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
internal import Foundation_Private.NSFileManager

#if os(macOS)
internal import QuarantinePrivate
#endif
#endif

internal import _FoundationCShims

extension CocoaError {
    fileprivate static func fileOperationError(_ code: CocoaError.Code,  _ sourcePath: String, _ destinationPath: String? = nil, variant: String? = nil) -> CocoaError {
        var info: [String : AnyHashable] = [NSSourceFilePathErrorKey:sourcePath]
        if let destinationPath {
            info[NSDestinationFilePathErrorKey] = destinationPath
        }
        return CocoaError.errorWithFilePath(code, sourcePath, variant: variant, userInfo: info)
    }

#if os(Windows)
    private static func fileOperationError(_ dwError: DWORD, _ suspectedErroneousPath: String, sourcePath: String? = nil, destinationPath: String? = nil, variant: String? = nil) -> CocoaError {
        var path = suspectedErroneousPath
        if let sourcePath, let destinationPath, dwError == ERROR_BUFFER_OVERFLOW {
            let lastLength = destinationPath.lastPathComponent.withFileSystemRepresentation {
                strlen($0!)
            }
            let fullLength = destinationPath.withFileSystemRepresentation {
                strlen($0!)
            }
            path = lastLength > MAX_PATH || fullLength > MAX_PATH ? destinationPath : sourcePath
        }

        var info: [String : AnyHashable] = [:]
        if let sourcePath {
            info[NSSourceFilePathErrorKey] = sourcePath
        }
        if let destinationPath {
            info[NSDestinationFilePathErrorKey] = destinationPath
        }
        return CocoaError.errorWithFilePath(path, win32: dwError, reading: false, variant: variant, userInfo: info)
    }

    fileprivate static func removeFileError(_ dwError: DWORD, _ path: String) -> CocoaError {
        var err = CocoaError.fileOperationError(dwError, path, variant: "Remove")
        if dwError == ERROR_DIR_NOT_EMPTY {
            err = CocoaError(.fileWriteNoPermission, userInfo: err.userInfo)
        }
        return err
    }

    fileprivate static func moveFileError(_ error: DWORD, _ src: URL, _ dst: URL) -> CocoaError {
        CocoaError.fileOperationError(error, src.path, sourcePath: src.path, destinationPath: dst.path, variant: "Move")
    }

    fileprivate static func linkFileError(_ error: DWORD, _ srcPath: String, _ dstPath: String) -> CocoaError {
        CocoaError.fileOperationError(error, srcPath, sourcePath: srcPath, destinationPath: dstPath, variant: "Link")
    }

    fileprivate static func copyFileError(_ error: DWORD, _ srcPath: String, _ dstPath: String) -> CocoaError {
        CocoaError.fileOperationError(error, srcPath, sourcePath: srcPath, destinationPath: dstPath, variant: "Copy")
    }
#else
    private static func fileOperationError(_ errNum: Int32, _ suspectedErroneousPath: String, sourcePath: String? = nil, destinationPath: String? = nil, variant: String? = nil) -> CocoaError {
        // Try to be a little bit more intelligent about which path should be reported in the error. In the case of ENAMETOOLONG, we can more accurately guess which path is causing the error without racily checking the file system after the fact. This may not be perfect in the face of operations which span file systems, or on file systems that only support names/paths less than NAME_MAX or PATH_MAX, but it's better than nothing.
        var erroneousPath = suspectedErroneousPath
        if let sourcePath, let destinationPath, errNum == ENAMETOOLONG {
            let lastLength = destinationPath.lastPathComponent.withFileSystemRepresentation { fsRep in
                guard let fsRep else { return 0 }
                return strnlen(fsRep, Int(NAME_MAX) + 1)
            }
            let fullLength = destinationPath.withFileSystemRepresentation { fsRep in
                guard let fsRep else { return 0 }
                return strnlen(fsRep, Int(PATH_MAX) + 1)
            }
            if lastLength > NAME_MAX || fullLength > PATH_MAX {
                erroneousPath = destinationPath
            } else {
                erroneousPath = sourcePath
            }
        }
        
        var userInfo: [String : AnyHashable] = [:]
        if let sourcePath {
            userInfo[NSSourceFilePathErrorKey] = sourcePath
        }
        if let destinationPath {
            userInfo[NSDestinationFilePathErrorKey] = destinationPath
        }
        return CocoaError.errorWithFilePath(erroneousPath, errno: errNum, reading: false, variant: variant, additionalUserInfo: userInfo)
    }
    
    fileprivate static func removeFileError(_ errNum: Int32, _ path: String) -> CocoaError {
        var err = CocoaError.fileOperationError(errNum, path, variant: "Remove")
        if errNum == ENOTEMPTY {
            err = CocoaError(.fileWriteNoPermission, userInfo: err.userInfo)
        }
        return err
    }
    
    fileprivate static func moveFileError(_ errNum: Int32, _ src: URL, _ dst: URL) -> CocoaError {
        CocoaError.fileOperationError(errNum, src.path, sourcePath: src.path, destinationPath: dst.path, variant: "Move")
    }
    
    fileprivate static func linkFileError(_ errNum: Int32, _ srcPath: String, _ dstPath: String) -> CocoaError {
        CocoaError.fileOperationError(errNum, srcPath, sourcePath: srcPath, destinationPath: dstPath, variant: "Link")
    }
    
    fileprivate static func copyFileError(_ errNum: Int32, _ srcPath: String, _ dstPath: String) -> CocoaError {
        CocoaError.fileOperationError(errNum, srcPath, sourcePath: srcPath, destinationPath: dstPath, variant: "Copy")
    }
#endif
}

extension FileManager {
    fileprivate func _shouldProceedAfter(error: Error, removingItemAtPath path: String) -> Bool {
        var delegateResponse: Bool?
        
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, removingItemAt: URL(fileURLWithPath: path))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, removingItemAtPath: path)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldProceedAfterError: error, removingItemAt: URL(fileURLWithPath: path))
            #endif
        }
        
        return delegateResponse ?? false
    }
    
    fileprivate func _shouldRemoveItemAtPath(_ path: String) -> Bool {
        var delegateResponse: Bool?
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldRemoveItemAt: URL(fileURLWithPath: path))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldRemoveItemAtPath: path)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldRemoveItemAt: URL(fileURLWithPath: path))
            #endif
        }
        return delegateResponse ?? true
    }
    
    fileprivate func _shouldProceedAfter(error: Error, copyingItemAtPath path: String, to dst: String) -> Bool {
        var delegateResponse: Bool?
        
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, copyingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, copyingItemAtPath: path, toPath: dst)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldProceedAfterError: error, copyingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            #endif
        }
        
        return delegateResponse ?? false
    }
    
    fileprivate func _shouldCopyItemAtPath(_ path: String, to dst: String) -> Bool {
        var delegateResponse: Bool?
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldCopyItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldCopyItemAtPath: path, toPath: dst)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldCopyItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            #endif
        }
        return delegateResponse ?? true
    }
    
    fileprivate func _shouldProceedAfter(error: Error, linkingItemAtPath path: String, to dst: String) -> Bool {
        var delegateResponse: Bool?
        
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, linkingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, linkingItemAtPath: path, toPath: dst)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldProceedAfterError: error, linkingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            #endif
        }
        
        return delegateResponse ?? false
    }
    
    fileprivate func _shouldLinkItemAtPath(_ path: String, to dst: String) -> Bool {
        var delegateResponse: Bool?
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldLinkItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldLinkItemAtPath: path, toPath: dst)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldLinkItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            #endif
        }
        return delegateResponse ?? true
    }
    
    fileprivate func _shouldProceedAfter(error: Error, movingItemAtPath path: String, to dst: String) -> Bool {
        var delegateResponse: Bool?
        
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, movingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldProceedAfterError: error, movingItemAtPath: path, toPath: dst)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldProceedAfterError: error, movingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            #endif
        }
        
        return delegateResponse ?? false
    }
    
    fileprivate func _shouldMoveItemAtPath(_ path: String, to dst: String) -> Bool {
        var delegateResponse: Bool?
        if let delegate = self.safeDelegate {
            #if FOUNDATION_FRAMEWORK
            delegateResponse = delegate.fileManager?(self, shouldMoveItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            
            if delegateResponse == nil {
                delegateResponse = delegate.fileManager?(self, shouldMoveItemAtPath: path, toPath: dst)
            }
            #else
            delegateResponse = delegate.fileManager(self, shouldMoveItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: dst))
            #endif
        }
        return delegateResponse ?? true
    }
}

#if !FOUNDATION_FRAMEWORK
struct NSFileManagerCopyOptions: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Void...) {}
}
struct NSFileManagerMoveOptions: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Void...) {}
}
#endif

private protocol LinkOrCopyDelegate {
#if os(Windows)
    typealias ErrorType = DWORD
#else
    typealias ErrorType = Int32
#endif

    func shouldPerformOnItemAtPath(_ path: String, to destination: String) -> Bool
    func throwIfNecessary(_ errno: ErrorType, _ source: String, _ destination: String) throws
    func throwIfNecessary(_ errno: any Error, _ source: String, _ destination: String) throws
    var extraCopyFileFlags: Int32 { get }
    var copyData: Bool { get }
}

private extension LinkOrCopyDelegate {
    var extraCopyFileFlags: Int32 { 0 }
}

#if canImport(Darwin)
private typealias RemoveFileCallback = @convention(c) (removefile_state_t, UnsafePointer<CChar>, UnsafeRawPointer) -> Int

extension removefile_state_t {
    fileprivate var errnum: Int32 {
        var num: Int32 = 0
        removefile_state_get(self, UInt32(REMOVEFILE_STATE_ERRNO), &num)
        return num
    }
    
    fileprivate func attachCallbacks(context: UnsafeRawPointer?, confirm: RemoveFileCallback, error: RemoveFileCallback) {
        removefile_state_set(self, UInt32(REMOVEFILE_STATE_CONFIRM_CONTEXT), context)
        removefile_state_set(self, UInt32(REMOVEFILE_STATE_CONFIRM_CALLBACK), unsafeBitCast(confirm, to: UnsafeRawPointer.self))
        removefile_state_set(self, UInt32(REMOVEFILE_STATE_ERROR_CONTEXT), context)
        removefile_state_set(self, UInt32(REMOVEFILE_STATE_ERROR_CALLBACK), unsafeBitCast(error, to: UnsafeRawPointer.self))
    }
}
#endif

enum _FileOperations {
    // MARK: removefile

#if os(Windows)
    static func removeFile(_ path: String, with filemanager: FileManager?) throws {
        try path.withNTPathRepresentation {
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            guard GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes) else {
                // NOTE: in the case that the 'stat' failed, we want to ensure
                // that we query if the item should be removed. If the item
                // should not be removed, we can continue, else we should check
                // if we should proceed after the error.
                guard filemanager?._shouldRemoveItemAtPath(path) ?? true else { return }

                let error = CocoaError.removeFileError(GetLastError(), path)
                guard (filemanager?._shouldProceedAfter(error: error, removingItemAtPath: path) ?? false) else {
                    throw error
                }
                return
            }
            if faAttributes.dwFileAttributes & FILE_ATTRIBUTE_READONLY == FILE_ATTRIBUTE_READONLY {
                guard SetFileAttributesW($0, faAttributes.dwFileAttributes & ~FILE_ATTRIBUTE_READONLY) else {
                    throw CocoaError.removeFileError(GetLastError(), path)
                }
            }
            if faAttributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == 0 || faAttributes.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT {
                guard filemanager?._shouldRemoveItemAtPath(path) ?? true else { return }
                if faAttributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY {
                    guard RemoveDirectoryW($0) else {
                        throw CocoaError.removeFileError(GetLastError(), path)
                    }
                    return
                } else {
                    guard DeleteFileW($0) else {
                        throw CocoaError.removeFileError(GetLastError(), path)
                    }
                    return
                }
            }

            var stack = [(path, false)]
            while let (directory, checked) = stack.popLast() {
                try directory.withNTPathRepresentation {
                    let ntpath = String(decodingCString: $0, as: UTF16.self)

                    guard checked || filemanager?._shouldRemoveItemAtPath(ntpath) ?? true else { return }

                    if RemoveDirectoryW($0) { return }
                    let dwError: DWORD = GetLastError()
                    guard dwError == ERROR_DIR_NOT_EMPTY else {
                        let error = CocoaError.removeFileError(dwError, directory)
                        guard (filemanager?._shouldProceedAfter(error: error, removingItemAtPath: ntpath) ?? false) else {
                            throw error
                        }
                        return
                    }
                    stack.append((directory, true))

                    for entry in _Win32DirectoryContentsSequence(path: directory, appendSlashForDirectory: false, prefix: [directory]) {
                        try entry.fileNameWithPrefix.withNTPathRepresentation {
                            let ntpath = String(decodingCString: $0, as: UTF16.self)

                            if entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY,
                                    entry.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != FILE_ATTRIBUTE_REPARSE_POINT {
                                if filemanager?._shouldRemoveItemAtPath(ntpath) ?? true {
                                    stack.append((ntpath, true))
                                }
                            } else {
                                if entry.dwFileAttributes & FILE_ATTRIBUTE_READONLY == FILE_ATTRIBUTE_READONLY {
                                    guard SetFileAttributesW($0, entry.dwFileAttributes & ~FILE_ATTRIBUTE_READONLY) else {
                                        throw CocoaError.removeFileError(GetLastError(), ntpath)
                                    }
                                }
                                if entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY {
                                    guard filemanager?._shouldRemoveItemAtPath(ntpath) ?? true else { return }
                                    if !RemoveDirectoryW($0) {
                                        let error = CocoaError.removeFileError(GetLastError(), entry.fileName)
                                        guard (filemanager?._shouldProceedAfter(error: error, removingItemAtPath: entry.fileNameWithPrefix) ?? false) else {
                                            throw error
                                        }
                                    }
                                } else {
                                    guard filemanager?._shouldRemoveItemAtPath(ntpath) ?? true else { return }
                                    if !DeleteFileW($0) {
                                        let error = CocoaError.removeFileError(GetLastError(), entry.fileName)
                                        guard (filemanager?._shouldProceedAfter(error: error, removingItemAtPath: entry.fileNameWithPrefix) ?? false) else {
                                            throw error
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
#else
    static func removeFile(_ path: String, with fileManager: FileManager?) throws {
        try path.withFileSystemRepresentation { rep in
            guard let rep else {
                throw CocoaError.errorWithFilePath(.fileNoSuchFile, path)
            }
            try Self._removeFile(rep, path, with: fileManager)
        }
    }
    
    #if canImport(Darwin)
    fileprivate class _FileRemoveContext {
        var error: CocoaError?
        var manager: FileManager?
        
        init(_ manager: FileManager?) {
            self.manager = manager
        }
    }
    
    private static func _removeFile(_ pathPtr: UnsafePointer<CChar>, _ pathStr: String, with fileManager: FileManager?) throws {
        let state = removefile_state_alloc()!
        defer { removefile_state_free(state) }
        
        let ctx = _FileRemoveContext(fileManager)
        try withExtendedLifetime(ctx) {
            let ctxPtr = Unmanaged.passUnretained(ctx).toOpaque()
            state.attachCallbacks(context: ctxPtr, confirm: { _, pathPtr, contextPtr in
                let context = Unmanaged<_FileOperations._FileRemoveContext>.fromOpaque(contextPtr).takeUnretainedValue()
                let path = String(cString: pathPtr)
                
                // Proceed unless the delegate says to skip
                return (context.manager?._shouldRemoveItemAtPath(path) ?? true) ? REMOVEFILE_PROCEED : REMOVEFILE_SKIP
            }, error: { state, pathPtr, contextPtr in
                let context = Unmanaged<_FileOperations._FileRemoveContext>.fromOpaque(contextPtr).takeUnretainedValue()
                let path = String(cString: pathPtr)
                
                let err = CocoaError.removeFileError(state.errnum, path)
                
                // Proceed only if the delegate says so
                if context.manager?._shouldProceedAfter(error: err, removingItemAtPath: path) ?? false {
                    return REMOVEFILE_PROCEED
                } else {
                    context.error = err
                    return REMOVEFILE_STOP
                }
            })
            
            let err = removefile(pathPtr, state, removefile_flags_t(REMOVEFILE_RECURSIVE))
            if err < 0 {
                if errno != 0 {
                    throw CocoaError.removeFileError(Int32(errno), pathStr)
                }
                throw CocoaError.removeFileError(state.errnum, pathStr)
            }
            
            if let error = ctx.error {
                throw error
            }
        }
    }
    #else
    private static func _removeFile(_ path: UnsafePointer<CChar>, _ pathStr: String, with fileManager: FileManager?) throws {
        let currentDirectoryPath = fileManager?.currentDirectoryPath ?? ""
        func resolve(path: String) -> String {
            if path.starts(with: "/") {
                return path
            } else {
                return currentDirectoryPath.appendingPathComponent(path)
            }
        }
        var stat = stat()
        guard lstat(path, &stat) == 0 && stat.isDirectory else {
            // Was not a directory, so unlink it
            guard fileManager?._shouldRemoveItemAtPath(pathStr) ?? true else { return }
            guard unlink(path) == 0 else {
                let error = CocoaError.removeFileError(errno, pathStr)
                if !(fileManager?._shouldProceedAfter(error: error, removingItemAtPath: pathStr) ?? false) {
                    throw error
                }
                return
            }
            return
        }
        
        guard fileManager?._shouldRemoveItemAtPath(resolve(path: pathStr)) ?? true else { return }
        let trivialResult = rmdir(path)
        if trivialResult == 0 {
            // Was an empty directory that we removed, so exit
            return
        } else if errno != ENOTEMPTY {
            // We failed for a reason other than the directory not being empty, so throw
            throw CocoaError.removeFileError(errno, resolve(path: pathStr))
        }
        
        let seq = _FTSSequence(path, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR | FTS_NOSTAT)
        let iterator = seq.makeIterator()
        var isFirst = true
        while let item = iterator.next() {
            switch item {
            case let .error(err, errPath):
                throw CocoaError.removeFileError(err, errPath)
                
            case let .entry(entry):
                let fts_path = entry.ftsEnt.fts_path!
                switch Int32(entry.ftsEnt.fts_info) {
                case FTS_DEFAULT, FTS_F, FTS_NSOK, FTS_SL, FTS_SLNONE:
                    let currentPathStr = resolve(path: String(cString: fts_path))
                    guard fileManager?._shouldRemoveItemAtPath(currentPathStr) ?? true else {
                        break
                    }
                    if unlink(fts_path) != 0 {
                        let error = CocoaError.removeFileError(errno, currentPathStr)
                        if !(fileManager?._shouldProceedAfter(error: error, removingItemAtPath: currentPathStr) ?? false) {
                            throw error
                        }
                    }
                case FTS_D:
                    if isFirst {
                        // The first directory was already approved above
                        isFirst = false
                        break
                    }
                    let currentPathStr = resolve(path: String(cString: fts_path))
                    if !(fileManager?._shouldRemoveItemAtPath(currentPathStr) ?? true) {
                        iterator.skipDescendants(of: entry, skipPostProcessing: true)
                    }
                case FTS_DP:
                    if rmdir(fts_path) != 0 {
                        let currentPathStr = resolve(path: String(cString: fts_path))
                        let error = CocoaError.removeFileError(errno, currentPathStr)
                        if !(fileManager?._shouldProceedAfter(error: error, removingItemAtPath: currentPathStr) ?? false) {
                            throw error
                        }
                    }
                case FTS_DNR, FTS_ERR, FTS_NS:
                    let currentPathStr = resolve(path: String(cString: fts_path))
                    throw CocoaError.removeFileError(entry.ftsEnt.fts_errno, currentPathStr)
                default:
                    break
                }
            }
        }
        
    }
    #endif
#endif
    
    // MARK: Move File
    
    static func moveFile(_ src: URL, to dst: URL, with fileManager: FileManager, options: NSFileManagerMoveOptions) throws {
#if os(Windows)
        try src.withUnsafeFileSystemRepresentation { pszSource in
            let source = String(cString: pszSource!)
            try dst.withUnsafeFileSystemRepresentation { pszDestination in
                let destination = String(cString: pszDestination!)

                guard fileManager._shouldMoveItemAtPath(source, to: destination) else { return }

                try source.withNTPathRepresentation { pwszSource in
                    var faSourceAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
                    if !GetFileAttributesExW(pwszSource, GetFileExInfoStandard, &faSourceAttributes) {
                        let error = CocoaError.moveFileError(GetLastError(), src, dst)
                        guard fileManager._shouldProceedAfter(error: error, movingItemAtPath: source, to: destination) else {
                            throw error
                        }
                        return
                    }

                    try destination.withNTPathRepresentation { pwszDestination in
                        var faDestinationAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
                        if GetFileAttributesExW(pwszDestination, GetFileExInfoStandard, &faDestinationAttributes) {
                            let error = CocoaError.moveFileError(GetLastError(), src, dst)
                            guard fileManager._shouldProceedAfter(error: error, movingItemAtPath: source, to: destination) else {
                                throw error
                            }
                        }

                        // `MoveFileExW` does not work if the source and
                        // destination are on different volumes and the source
                        // is a directory. In that case, we need to do a
                        // recursive copy and then remove the source.
                        if PathIsSameRootW(pwszSource, pwszDestination) ||
                                faSourceAttributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != FILE_ATTRIBUTE_DIRECTORY {
                            if !MoveFileExW(pwszSource, pwszDestination, MOVEFILE_COPY_ALLOWED | MOVEFILE_WRITE_THROUGH) {
                                let error = CocoaError.moveFileError(GetLastError(), src, dst)
                                guard fileManager._shouldProceedAfter(error: error, movingItemAtPath: source, to: destination) else {
                                    throw error
                                }
                            }
                        } else {
                            var stack: [String] = [source]
                            while let entry = stack.popLast() {
                                do {
                                    try entry.withNTPathRepresentation { pwszEntry in
                                        var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
                                        guard GetFileAttributesExW(pwszEntry, GetFileExInfoStandard, &faAttributes) else {
                                            throw CocoaError.moveFileError(GetLastError(), src, dst)
                                        }

                                        var pwszDestination: PWSTR? = nil
                                        guard SUCCEEDED(PathAllocCombine(destination, entry, PATHCCH_ALLOW_LONG_PATHS, &pwszDestination)) else {
                                            throw CocoaError.moveFileError(GetLastError(), src, dst)
                                        }
                                        defer { LocalFree(pwszDestination) }

                                        if faAttributes.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT {
                                            let aliasee = try fileManager.destinationOfSymbolicLink(atPath: entry)

                                            // TODO(compnerd) - is there a way to avoid the round-trip of decoding, encoding here?
                                            let destination = String(decodingCString: pwszDestination!, as: UTF16.self)

                                            var faDestinationAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
                                            if GetFileAttributesExW(pwszDestination, GetFileExInfoStandard, &faDestinationAttributes) {
                                                try removeFile(destination, with: fileManager)
                                            }
                                            try fileManager.createSymbolicLink(atPath: destination, withDestinationPath: aliasee)
                                        } else {
                                            if faAttributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY {
                                                guard CreateDirectoryW(pwszDestination, nil) else {
                                                    throw CocoaError.moveFileError(GetLastError(), src, dst)
                                                }
                                                stack.append(entry)
                                                for entry in _Win32DirectoryContentsSequence(path: entry, appendSlashForDirectory: true) {
                                                    stack.append(entry.fileName)
                                                }
                                            } else {
                                                guard CopyFileW(pwszEntry, pwszDestination, true) else {
                                                    throw CocoaError.moveFileError(GetLastError(), src, dst)
                                                }
                                            }
                                        }
                                    }
                                } catch let error {
                                    guard fileManager._shouldProceedAfter(error: error, movingItemAtPath: source, to: destination) else {
                                        throw error
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
#else
        try src.withUnsafeFileSystemRepresentation { srcPath in
            guard let srcPath else {
                throw CocoaError.errorWithFilePath(.fileNoSuchFile, src)
            }
            
            try dst.withUnsafeFileSystemRepresentation { dstPath in
                guard let dstPath else {
                    throw CocoaError.errorWithFilePath(.fileNoSuchFile, dst)
                }
                
                guard fileManager._shouldMoveItemAtPath(String(cString: srcPath), to: String(cString: dstPath)) else { return }
                
                // If the destination path already exists, we're going to bail out completely & set the error.
                var fileInfoBuffer = stat()
                var delegateIgnoredOverwriteError = false
                if lstat(dstPath, &fileInfoBuffer) == 0 {
                    // The lstat succeeded, so this is the error case for a file existing at the destination
                    // If the last components are case-insensitively the same, then we might be dealing with a case-only rename which should proceed ...
                    var shouldProceed = false
                    if src.lastPathComponent.compare(dst.lastPathComponent, options: [.caseInsensitive]) == .orderedSame {
                        #if FOUNDATION_FRAMEWORK
                        // TODO: Support case-only rename in swift-foundation
                        if let srcAttrs = try? src.resourceValues(forKeys: [.parentDirectoryURLKey]), let dstAttrs = try? dst.resourceValues(forKeys: [.parentDirectoryURLKey, .volumeSupportsCasePreservedNamesKey, .volumeSupportsCaseSensitiveNamesKey]) {
                            
                            // ... but not if the source and destination are in different directories, meaning they're definitely different directory entries ...
                            if srcAttrs.parentDirectory == dstAttrs.parentDirectory {
                                // ... but only in volumes that are case insensitive, but case preserving.
                                if dstAttrs.volumeSupportsCasePreservedNames! && !dstAttrs.volumeSupportsCaseSensitiveNames! {
                                    shouldProceed = true
                                }
                            }
                        }
                        #endif
                    }
                    
                    if !shouldProceed {
                        let err = CocoaError.moveFileError(EEXIST, src, dst)
                        guard fileManager._shouldProceedAfter(error: err, movingItemAtPath: String(cString: srcPath), to: String(cString: dstPath)) else {
                            throw err
                        }
                        delegateIgnoredOverwriteError = true
                    }
                }
                
                // First, we should just rename (who knows? We might get lucky).
                var renameError = rename(srcPath, dstPath) != 0
                let renameErrno = errno
                
#if os(macOS) && FOUNDATION_FRAMEWORK
                // If the rename was successful, stamp with DO_NOT_TRANSLOCATE, if requested. If rename failed with EXDEV, the copy operation will take care of it instead. Ignore failure. 26556142.
                if !renameError && options.contains(.allowRunningResultInPlace) {
                    if let qtn = _qtn_file_alloc() {
                        defer { _qtn_file_free(qtn) }
                        
                        if _qtn_file_init_with_path(qtn, dstPath) == 0 {
                            var flags = _qtn_file_get_flags(qtn)
                            if flags & QTN_FLAG_DO_NOT_TRANSLOCATE.rawValue == 0 {
                                flags |= QTN_FLAG_DO_NOT_TRANSLOCATE.rawValue
                                _qtn_file_set_flags(qtn, flags);
                                _qtn_file_apply_to_path(qtn, dstPath);
                            }
                        }
                    }
                }
#endif
                
#if (os(macOS) || os(iOS)) && FOUNDATION_FRAMEWORK
                if renameError && renameErrno == ENOENT {
                    // Could this perhaps be a faulted-out iCloud file that we're attempting to move?
                    var handled: ObjCBool = false
                    try fileManager._handleFaultedOutCloudDoc(fromSource: src, toDestination: dst, handled: &handled)
                    if handled.boolValue {
                        renameError = false
                    }
                }
#endif
                
                if renameError {
                    if renameErrno == EXDEV {
                        // We tried to move something across a device. We should copy and then unlink the original.
                        var copyOptions: NSFileManagerCopyOptions = []
#if os(macOS) && FOUNDATION_FRAMEWORK
                        if options.contains(.allowRunningResultInPlace) {
                            copyOptions.insert(.allowRunningResultInPlace)
                        }
#endif
                        
                        do {
                            try Self.copyFile(src.path, to: dst.path, with: fileManager, options: copyOptions)
                        } catch let copyError as CocoaError {
                            // The error occurred on the copy operation, however we don't want to report those paths - we want to report the paths on the top-level item; the one the move was requested for. We'll wrap the copy operation error in the underlying error key, but we'll pick up the error code from the underlying error itself.
                            
                            if !delegateIgnoredOverwriteError {
                                // Remove the incomplete copy at the destination, but only if the delegate didn't ignore the overwrite failure.
                                try? Self.removeFile(dst.path, with: nil)
                            }
                            
                            throw CocoaError(copyError.code, userInfo: [
                                NSFilePathErrorKey : src.path,
                                NSDestinationFilePathErrorKey : dst.path,
                                NSUserStringVariantErrorKey : "Move",
                                NSUnderlyingErrorKey : copyError
                            ])
                        }
                        
                        // The copy was successful. Remove the original, but only if the delegate didn't ignore the rename failure.
                        do {
                            try Self.removeFile(src.path, with: nil)
                        } catch let removeError as CocoaError {
                            // Like the error from the copy operation above, make the "Remove" error the underlying error to a "Move" error.
                            throw CocoaError(removeError.code, userInfo: [
                                NSFilePathErrorKey : src.path,
                                NSDestinationFilePathErrorKey : dst.path,
                                NSUserStringVariantErrorKey : "Move",
                                NSUnderlyingErrorKey : removeError
                            ])
                        }
                    } else {
                        // The error was something other than EXDEV, which means the rename() failed. The error codes for the rename need to be translated into something good for Cocoa domain errors.
                        let renameError = CocoaError.moveFileError(renameErrno, src, dst)
                        guard fileManager._shouldProceedAfter(error: renameError, movingItemAtPath: src.path, to: dst.path) else {
                            throw renameError
                        }
                    }
                }
            }
        }
#endif
    }
    
    // MARK: Link/Copy File

#if os(Windows)
    private static func linkOrCopyFile(_ src: String, dst: String, with fileManager: FileManager, delegate: some LinkOrCopyDelegate) throws {
        let bCopyFile = delegate.copyData
        try src.withNTPathRepresentation { pwszSource in
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            guard GetFileAttributesExW(pwszSource, GetFileExInfoStandard, &faAttributes) else {
                throw CocoaError.fileOperationError(.fileReadNoSuchFile, src, dst, variant: bCopyFile ? "Copy" : "Link")
            }

            guard delegate.shouldPerformOnItemAtPath(src, to: dst) else { return }

            try dst.withNTPathRepresentation { pwszDestination in
                if faAttributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY {
                    do {
                        try fileManager.createDirectory(atPath: dst, withIntermediateDirectories: true)
                    } catch {
                        try delegate.throwIfNecessary(error, src, dst)
                    }
                    for item in _Win32DirectoryContentsSequence(path: src, appendSlashForDirectory: true) {
                        try linkOrCopyFile(src.appendingPathComponent(item.fileName), dst: dst.appendingPathComponent(item.fileName), with: fileManager, delegate: delegate)
                    }
                } else if bCopyFile || faAttributes.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT {
                    var ExtendedParameters: COPYFILE2_EXTENDED_PARAMETERS = .init()
                    ExtendedParameters.dwSize = DWORD(MemoryLayout<COPYFILE2_EXTENDED_PARAMETERS>.size)
                    ExtendedParameters.dwCopyFlags = COPY_FILE_FAIL_IF_EXISTS | COPY_FILE_COPY_SYMLINK | COPY_FILE_NO_BUFFERING | COPY_FILE_OPEN_AND_COPY_REPARSE_POINT

                    if FAILED(CopyFile2(pwszSource, pwszDestination, &ExtendedParameters)) {
                        try delegate.throwIfNecessary(GetLastError(), src, dst)
                    }
                } else {
                    do {
                        try fileManager.createSymbolicLink(atPath: dst, withDestinationPath: src)
                    } catch {
                        try delegate.throwIfNecessary(error, src, dst)
                    }
                }
            }
        }
    }
#else
    #if !canImport(Darwin)
    private static func _copyRegularFile(_ srcPtr: UnsafePointer<CChar>, _ dstPtr: UnsafePointer<CChar>, delegate: some LinkOrCopyDelegate) throws {
        var fileInfo = stat()
        guard stat(srcPtr, &fileInfo) >= 0 else {
            try delegate.throwIfNecessary(errno, String(cString: srcPtr), String(cString: dstPtr))
            return
        }

        let srcfd = open(srcPtr, O_RDONLY)
        guard srcfd >= 0 else {
            try delegate.throwIfNecessary(errno, String(cString: srcPtr), String(cString: dstPtr))
            return
        }
        defer { close(srcfd) }

        let dstfd = open(dstPtr, O_WRONLY | O_CREAT | O_EXCL | O_TRUNC, 0o666)
        guard dstfd >= 0 else {
            try delegate.throwIfNecessary(errno, String(cString: srcPtr), String(cString: dstPtr))
            return
        }
        defer { close(dstfd) }

        // Set the file permissions using fchmod() instead of when open()ing to avoid umask() issues
        let permissions = fileInfo.st_mode & ~S_IFMT
        guard fchmod(dstfd, permissions) == 0 else {
            try delegate.throwIfNecessary(errno, String(cString: srcPtr), String(cString: dstPtr))
            return
        }

        if fileInfo.st_size == 0 {
            // no copying required
            return
        }
        
        let total: Int = Int(fileInfo.st_size)
        let chunkSize: Int = Int(fileInfo.st_blksize)
        var current: off_t = 0
        
        while current < total {
            guard sendfile(dstfd, srcfd, &current, Swift.min(total - Int(current), chunkSize)) != -1 else {
                try delegate.throwIfNecessary(errno, String(cString: srcPtr), String(cString: dstPtr))
                return
            }
        }
    }
    #endif

    private static func _linkOrCopyFile(_ srcPtr: UnsafePointer<CChar>, _ dstPtr: UnsafePointer<CChar>, with fileManager: FileManager, delegate: some LinkOrCopyDelegate) throws {
        try withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { buffer in
            let dstLen = Platform.copyCString(dst: buffer.baseAddress!, src: dstPtr, size: FileManager.MAX_PATH_SIZE)
            let srcLen = strlen(srcPtr)
            let dstAppendPtr = buffer.baseAddress!.advanced(by: dstLen)
            let remainingBuffer = FileManager.MAX_PATH_SIZE - dstLen
            
            let seq = _FTSSequence(srcPtr, .init(FTS_PHYSICAL | FTS_NOCHDIR))
            let iterator = seq.makeIterator()
            while let item = iterator.next() {
                switch item {
                case let .error(errno, path):
                    throw CocoaError.errorWithFilePath(path, errno: errno, reading: true)
                    
                case let .entry(entry):
                    let fts_path = entry.ftsEnt.fts_path!
                    let trimmedPathPtr = fts_path.advanced(by: srcLen)
                    Platform.copyCString(dst: dstAppendPtr, src: trimmedPathPtr, size: remainingBuffer)
                    
                    // we don't want to ask the delegate on the way back -up- the hierarchy if they want to copy a directory they've already seen and therefore already said "YES" to.
                    guard entry.ftsEnt.fts_info == FTS_DP || delegate.shouldPerformOnItemAtPath(String(cString: fts_path), to: String(cString: buffer.baseAddress!)) else {
                        if entry.ftsEnt.fts_info == FTS_D {
                            iterator.skipDescendants(of: entry, skipPostProcessing: true)
                        }
                        continue
                    }
                    
                    let extraFlags = entry.ftsEnt.fts_level == 0 ? delegate.extraCopyFileFlags : 0
                    
                    switch Int32(entry.ftsEnt.fts_info) {
                    case FTS_D:
                        // Directory being visited in pre-order - create it with whatever default perms will be on the destination.
                        #if canImport(Darwin)
                        if copyfile(fts_path, buffer.baseAddress!, nil, copyfile_flags_t(COPYFILE_DATA | COPYFILE_EXCL | COPYFILE_NOFOLLOW | extraFlags)) != 0 {
                            try delegate.throwIfNecessary(errno, String(cString: fts_path), String(cString: buffer.baseAddress!))
                        }
                        #else
                        do {
                            try fileManager.createDirectory(atPath: String(cString: buffer.baseAddress!), withIntermediateDirectories: true)
                        } catch {
                            try delegate.throwIfNecessary(error, String(cString: fts_path), String(cString: buffer.baseAddress!))
                        }
                        #endif
                        
                    case FTS_DP:
                        // Directory being visited in post-order - copy the permissions over.
                        #if canImport(Darwin)
                        if copyfile(fts_path, buffer.baseAddress!, nil, copyfile_flags_t(COPYFILE_METADATA | COPYFILE_NOFOLLOW | extraFlags)) != 0 {
                            try delegate.throwIfNecessary(errno, String(cString: fts_path), String(cString: buffer.baseAddress!))
                        }
                        #else
                        do {
                            let attributes = try fileManager.attributesOfItem(atPath: String(cString: fts_path))
                            try fileManager.setAttributes(attributes, ofItemAtPath: String(cString: buffer.baseAddress!))
                        } catch {
                            try delegate.throwIfNecessary(error, String(cString: fts_path), String(cString: buffer.baseAddress!))
                        }
                        #endif
                        
                    case FTS_SL: fallthrough    // Symlink.
                    case FTS_SLNONE:            // Symlink with no target.
                        // Do what the documentation says (and what linkPath:toPath:handler: does) - copy the symlink, instead of creating a hard link.
                        #if canImport(Darwin)
                        var flags: Int32
                        if delegate.copyData {
                            flags = COPYFILE_CLONE | COPYFILE_ALL | COPYFILE_EXCL | COPYFILE_NOFOLLOW | extraFlags
                        } else {
                            flags = COPYFILE_DATA | COPYFILE_METADATA | COPYFILE_EXCL | COPYFILE_NOFOLLOW | extraFlags
                        }
                        if copyfile(fts_path, buffer.baseAddress!, nil, copyfile_flags_t(flags)) != 0 {
                            try delegate.throwIfNecessary(errno, String(cString: fts_path), String(cString: buffer.baseAddress!))
                        }
                        #else
                        try withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { tempBuff in
                            tempBuff.initialize(repeating: 0)
                            defer { tempBuff.deinitialize() }
                            let len = readlink(fts_path, tempBuff.baseAddress!, FileManager.MAX_PATH_SIZE - 1)
                            if len >= 0, symlink(tempBuff.baseAddress!, buffer.baseAddress!) != -1 {
                                return
                            }
                            try delegate.throwIfNecessary(errno, String(cString: fts_path), String(cString: buffer.baseAddress!))
                        }
                        #endif
                        
                    case FTS_DEFAULT: fallthrough   // Something not defined anywhere else.
                    case FTS_F:                     // Regular file.
                        if delegate.copyData {
                            #if canImport(Darwin)
                            if copyfile(fts_path, buffer.baseAddress!, nil, copyfile_flags_t(COPYFILE_CLONE | COPYFILE_ALL | COPYFILE_EXCL | COPYFILE_NOFOLLOW | extraFlags)) != 0 {
                                try delegate.throwIfNecessary(errno, String(cString: fts_path), String(cString: buffer.baseAddress!))
                            }
                            #else
                            try Self._copyRegularFile(fts_path, buffer.baseAddress!, delegate: delegate)
                            #endif
                        } else {
                            if link(fts_path, buffer.baseAddress!) != 0 {
                                try delegate.throwIfNecessary(errno, String(cString: fts_path), String(cString: buffer.baseAddress!))
                            }
                        }
                        
                        // Error returns
                    case FTS_DNR: fallthrough   // Directory cannot be read.
                    case FTS_ERR: fallthrough   // Some error occurred, but we don't know what.
                    case FTS_NS:                // No stat(2) information is available.
                        try delegate.throwIfNecessary(entry.ftsEnt.fts_errno, String(cString: fts_path), String(cString: buffer.baseAddress!))
                        
                    default: break
                    }
                }
            }
        }
    }
    
    private static func linkOrCopyFile(_ src: String, dst: String, with fileManager: FileManager, delegate: some LinkOrCopyDelegate) throws {
        try src.withFileSystemRepresentation { srcPtr in
            guard let srcPtr else {
                throw CocoaError.errorWithFilePath(.fileReadNoSuchFile, src)
            }
            try dst.withFileSystemRepresentation { dstPtr in
                guard let dstPtr else {
                    throw CocoaError.errorWithFilePath(.fileNoSuchFile, dst)
                }
                try Self._linkOrCopyFile(srcPtr, dstPtr, with: fileManager, delegate: delegate)
            }
        }
    }
#endif

    static func copyFile(_ src: String, to dst: String, with fileManager: FileManager, options: NSFileManagerCopyOptions) throws {
        struct CopyFileDelegate : LinkOrCopyDelegate {
            let copyData = true
            let extraCopyFileFlags: Int32
            let fileManager: FileManager

            init(inPlace: Bool, fileManager: FileManager) {
                self.fileManager = fileManager
                #if canImport(Darwin)
                extraCopyFileFlags = inPlace ? COPYFILE_RUN_IN_PLACE : 0
                #else
                extraCopyFileFlags = 0
                #endif
            }
            
            func shouldPerformOnItemAtPath(_ path: String, to destination: String) -> Bool {
                fileManager._shouldCopyItemAtPath(path, to: destination)
            }

            func throwIfNecessary(_ error: ErrorType, _ source: String, _ destination: String) throws {
                let error = CocoaError.copyFileError(error, source, destination)
                guard fileManager._shouldProceedAfter(error: error, copyingItemAtPath: source, to: destination) else {
                    throw error
                }
            }

            func throwIfNecessary(_ error: any Error, _ source: String, _ destination: String) throws {
                guard fileManager._shouldProceedAfter(error: error, copyingItemAtPath: source, to: destination) else {
                    throw error
                }
            }
        }

        var inPlace = false
        #if FOUNDATION_FRAMEWORK
        if options.contains(.allowRunningResultInPlace) {
            inPlace = true
        }
        #endif
        try Self.linkOrCopyFile(src, dst: dst, with: fileManager, delegate: CopyFileDelegate(inPlace: inPlace, fileManager: fileManager))
    }
    
    static func linkFile(_ src: String, to dst: String, with fileManager: FileManager) throws {
        struct LinkFileDelegate : LinkOrCopyDelegate {
            let copyData = false
            let fileManager: FileManager
            
            init(_ fileManager: FileManager) {
                self.fileManager = fileManager
            }
            
            func shouldPerformOnItemAtPath(_ path: String, to destination: String) -> Bool {
                fileManager._shouldLinkItemAtPath(path, to: destination)
            }

            func throwIfNecessary(_ error: ErrorType, _ source: String, _ destination: String) throws {
                let error = CocoaError.linkFileError(error, source, destination)
                guard fileManager._shouldProceedAfter(error: error, linkingItemAtPath: source, to: destination) else {
                    throw error
                }
            }

            func throwIfNecessary(_ error: any Error, _ source: String, _ destination: String) throws {
                guard fileManager._shouldProceedAfter(error: error, linkingItemAtPath: source, to: destination) else {
                    throw error
                }
            }
        }
        try Self.linkOrCopyFile(src, dst: dst, with: fileManager, delegate: LinkFileDelegate(fileManager))
    }
}
