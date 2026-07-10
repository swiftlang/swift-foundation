//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#if !NO_FILESYSTEM
internal import DarwinPrivate // for VREG
#endif
#endif

internal import _FoundationCShims

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
#elseif os(Emscripten)
@preconcurrency import EmscriptenLibc
#endif

#if !NO_FILESYSTEM

// MARK: - Helpers

#if os(Windows)
private func openFileDescriptorProtected(path: UnsafePointer<UInt16>, flags: Int32, options: Data.WritingOptions) -> Int32 {
    var fd: CInt = 0
    _ = _wsopen_s(&fd, path, flags, _SH_DENYNO, _S_IREAD | _S_IWRITE)
    return fd
}
#else
private func openFileDescriptorProtected(path: UnsafePointer<CChar>, flags: Int32, options: Data.WritingOptions) -> Int32 {
#if FOUNDATION_FRAMEWORK
    // Use file protection on this platform
    return _NSOpenFileDescriptor_Protected(path, Int(flags), options, 0o666)
#else
    return open(path, flags, 0o666)
#endif
}

#if !os(Windows)
/// at-style equivalent of `openFileDescriptorProtected` that takes a parent dirfd plus a relative name.
private func openatFileDescriptorProtected(dirfd: Int32, name: UnsafePointer<CChar>, flags: Int32, options: Data.WritingOptions, mode: mode_t) -> Int32 {
#if FOUNDATION_FRAMEWORK
    return _NSOpenAtFileDescriptor_Protected(dirfd, name, Int(flags), options, Int(mode))
#else
    return openat(dirfd, name, flags, mode)
#endif
}
#endif
#endif

#if !os(Windows)
private var minimalOpenFlagsForDirectories: Int32 {
#if canImport(Darwin)
    O_SEARCH
#elseif os(WASI) || os(Emscripten)
    O_DIRECTORY | O_RDONLY
#else
    O_DIRECTORY | O_PATH
#endif
}
#endif

#if !os(Windows)
private typealias TemporaryFilePermissions = mode_t
#else
// Presently unimplemented on Windows
private typealias TemporaryFilePermissions = Void
#endif


private func writeToFileDescriptorWithProgress(_ fd: Int32, buffer: RawSpan, reportProgress: Bool) throws -> Int {
    // Fetch this once
    let length = buffer.byteCount
    
    let preferredChunkSize: Int
    let localProgress: Progress?
    if reportProgress && Progress.current() != nil {
        // To report progress, we have to try writing in smaller chunks than the whole file.
        // Aim for about 1% increments in progress updates.
        preferredChunkSize = max(length / 100, 1024 * 4)
        localProgress = Progress(totalUnitCount: Int64(length))
    } else {
        preferredChunkSize = length
        localProgress = nil
    }

    var remaining = buffer
    while !remaining.isEmpty {
        if let localProgress, localProgress.isCancelled {
            throw CocoaError(.userCancelled)
        }
        
        // Don't ever attempt to write more than (2GB - 1 byte). Some platforms will return an error over that amount.
        let numBytesRequested = CInt(clamping: min(preferredChunkSize, Int(CInt.max)))
        let smallestAmountToRead = min(Int(numBytesRequested), remaining.byteCount)
        let chunk = remaining.extracting(first: smallestAmountToRead)
        var numBytesWritten: CInt
        repeat {
            if let localProgress, localProgress.isCancelled {
                throw CocoaError(.userCancelled)
            }
            numBytesWritten = chunk.withUnsafeBytes { buf in
#if os(Windows)
                _write(fd, buf.baseAddress, CUnsignedInt(buf.count))
#else
                CInt(clamping: write(fd, buf.baseAddress!, buf.count))
#endif
            }
            
            if numBytesWritten < 0 {
                let savedErrno = errno
                logFileIOErrno(savedErrno, at: "write")
                errno = savedErrno
                // The write failed. Return a value which causes an error.
                return -1
            } else if numBytesWritten == 0 {
                // Return the number of bytes written so far (which is compatible with the way write() would work with just one call)
                break
            } else {
                remaining = remaining.extracting(droppingFirst: Int(numBytesWritten))
                if let localProgress {
                    localProgress.completedUnitCount = Int64(length - remaining.byteCount)
                }
                // Anytime we write less than actually requested, stop, since the length is considered the "max" for socket calls
                if numBytesWritten < chunk.byteCount {
                    break
                }
            }
        } while numBytesWritten < 0 && errno == EINTR
    }
    
    let bytesWritten = length - remaining.byteCount
    return bytesWritten
}

private func cleanupTemporaryDirectory(at inPath: String?) {
    guard let inPath else { return }
    #if canImport(Darwin) || os(Linux)
    // Since we expect the directory to be empty at this point, try rmdir which is much faster than Darwin's removefile(3) for known empty directories
    if inPath.withFileSystemRepresentation({ $0.flatMap(rmdir) }) == 0 {
        return
    }
    #endif
    // Attempt to use FileManager, ignore error
    try? FileManager.default.removeItem(atPath: inPath)
}

/// Creates a temporary file for atomic writing of `inPath` in the destination's parent directory.
/// If `destDirfd` is -1, then `destinationPath` should be the full path.
#if os(WASI) || os(Emscripten)
@available(*, unavailable, message: "WASI does not have temporary directories")
#endif
private func createTemporaryFile(destDirfd: Int32, destinationPath: String, inPath: borrowing some FileSystemRepresentable & ~Copyable, options: Data.WritingOptions, permissions: TemporaryFilePermissions, variant: String? = nil) throws -> (Int32, String) {
#if os(WASI) || os(Emscripten)
    // WASI/Emscripten does not have temp directories
    throw CocoaError(.featureUnsupported)
#else
    // When `destDirfd == -1`, build a full-path template and open the file by path.
    // Otherwise the template is a basename only and the file is created relative to
    // `destDirfd` via openat.
    let pidString = String(ProcessInfo.processInfo.processIdentifier, radix: 16, uppercase: true)
    let template: String
    if destDirfd == -1 {
        var directoryPath = destinationPath.deletingLastPathComponent()
        if !directoryPath.isEmpty && directoryPath.last! != "/" {
            directoryPath.append("/")
        }
        template = directoryPath + ".dat.nosync" + pidString + ".XXXXXX"
    } else {
        template = ".dat.nosync" + pidString + ".XXXXXX"
    }
    let maxCount = 7
    for _ in 0 ..< maxCount {
#if FOUNDATION_FRAMEWORK
        let (sandboxResult, amkrErrno) = inPath.withFileSystemRepresentation { inPathFileSystemRep -> ((Int32, String)?, Int32?) in
            guard let inPathFileSystemRep else {
                return (nil, nil)
            }
            // First, try _amkrtemp to carry over any sandbox extensions for inPath to the temporary file (even if the application isn't sandboxed)
            guard let uniqueTempFile = _amkrtemp(inPathFileSystemRep) else {
                return (nil, errno)
            }
            defer { free(uniqueTempFile) }
            let fd: Int32
            let returnedName: String
            if destDirfd == -1 {
                returnedName = String(cString: uniqueTempFile)
                fd = openFileDescriptorProtected(path: uniqueTempFile, flags: O_CREAT | O_EXCL | O_RDWR, options: options)
            } else {
                returnedName = String(cString: uniqueTempFile).lastPathComponent
                fd = returnedName.withFileSystemRepresentation { basenameRep -> Int32 in
                    guard let basenameRep else {
                        errno = EINVAL
                        return -1
                    }
                    return openatFileDescriptorProtected(dirfd: destDirfd, name: basenameRep, flags: O_CREAT | O_EXCL | O_RDWR, options: options, mode: permissions)
                }
            }
            if fd >= 0 {
                return ((fd, returnedName), nil)
            }
            return (nil, errno)
        }
        
        // If _amkrtemp succeeded, return its result
        if let sandboxResult {
            return sandboxResult
        }
        
        // If we have no result and also no errno, just fail immediately because we failed to produce a file system representation for the path
        guard let amkrErrno else {
            throw CocoaError.errorWithFilePath(.fileReadInvalidFileName, inPath.path)
        }
        
        // If _amkrtemp failed with EEXIST, just retry
        if amkrErrno == EEXIST {
            continue
        }
        // Otherwise, fall through to mktemp below
#endif
        
        let result: (Int32, String)? = try template.withMutableFileSystemRepresentation { templateFileSystemRep in
            guard let templateFileSystemRep else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            
            // The warning diligently tells us we shouldn't be using mktemp() because blindly opening the returned path opens us up to a TOCTOU race. However, in this case, we're being careful by doing O_CREAT|O_EXCL and repeating, just like the implementation of mkstemp.
            // Furthermore, we can't compatibly switch to mkstemp()/mkstemp_dprotected_np() until we have the ability to set fchmod correctly, which requires the ability to query the current umask, which we don't have. (22033100)
#if os(Windows)
            guard _mktemp_s(templateFileSystemRep, strlen(templateFileSystemRep) + 1) == 0 else {
                throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false, variant: variant)
            }
#else
            @diagnose(DeprecatedDeclaration, as: ignored)
            func _mktemp(_ templateFileSystemRep: UnsafeMutablePointer<CChar>!) -> UnsafeMutablePointer<CChar>! {
                mktemp(templateFileSystemRep)
            }
            
            guard _mktemp(templateFileSystemRep) != nil else {
                throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false, variant: variant)
            }
#endif

            let fd: Int32
#if os(Windows)
            assert(destDirfd == -1, "openat is unavailable on Windows")
            fd = try String(cString: templateFileSystemRep).withNTPathRepresentation {
                openFileDescriptorProtected(path: $0, flags: _O_BINARY | _O_CREAT | _O_EXCL | _O_RDWR, options: options)
            }
#else
            if destDirfd == -1 {
                fd = openFileDescriptorProtected(path: templateFileSystemRep, flags: O_CREAT | O_EXCL | O_RDWR, options: options)
            } else {
                fd = openatFileDescriptorProtected(dirfd: destDirfd, name: templateFileSystemRep, flags: O_CREAT | O_EXCL | O_RDWR, options: options, mode: permissions)
            }
#endif

            if fd >= 0 {
                // Got a good fd
                return (fd, String(cString: templateFileSystemRep))
            }
            
            // If the file exists, we repeat. Otherwise throw the error.
            if errno != EEXIST {
                #if FOUNDATION_FRAMEWORK
                let debugDescription = "Creating a temporary file via mktemp failed. Creating the temporary file via _amkrtemp previously also failed with errno \(amkrErrno)"
                #else
                let debugDescription: String? = nil
                #endif
                throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false, variant: variant, debugDescription: debugDescription)
            }

            // Try again
            return nil
        }
        
        if let result {
            return result
        }
    }
    // We hit max count, prevent an infinite loop; even if the error is obscure
    throw CocoaError(.fileWriteUnknown)
#endif // os(WASI)
}

/// Returns `(file descriptor, temporary file name, temporary directory file descriptor, temporary directory path)`
/// Caller is responsible for calling `close` on the `fd: Int32` file descriptor and calling `cleanupTemporaryDirectory` on the temporary directory path. The temporary directory path may be nil, if it does not need to be cleaned up.
/// Caller must also close the `tempDirfd: Int32` file descriptor if it's different than `fd`.
#if os(WASI) || os(Emscripten)
@available(*, unavailable, message: "WASI does not have temporary directories")
#endif
private func createProtectedTemporaryFile(destDirfd: Int32, destinationPath: String, inPath: borrowing some FileSystemRepresentable & ~Copyable, options: Data.WritingOptions, permissions: TemporaryFilePermissions, variant: String? = nil) throws -> (fd: Int32, name: String, tempDirfd: Int32, cleanupPath: String?) {
#if os(WASI) || os(Emscripten)
    // WASI/Emscripten does not have temp directories
    throw CocoaError(.featureUnsupported)
#else
#if FOUNDATION_FRAMEWORK
    if _foundation_sandbox_check(getpid(), nil) != 0 {
        // Convert the path back into a string
        let url = URL(fileURLWithPath: destinationPath, isDirectory: false)
        let replacementDir: String
        do {
            replacementDir = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true).path(percentEncoded: false)
        } catch {
            if let variant, let cocoaError = error as? CocoaError {
                let code = cocoaError.code
                var userInfo = cocoaError.userInfo
                userInfo[NSUserStringVariantErrorKey] = variant

                throw CocoaError(code, userInfo: userInfo)
            } else {
                throw error
            }
        }

        let updatedOptions = _NSDataWritingOptionsForRelocatedAtomicWrite(options, destinationPath)
        let basename = destinationPath.lastPathComponent
        let openedDirfd = replacementDir.withFileSystemRepresentation { rep -> Int32 in
            guard let rep else {
                errno = EINVAL
                return -1
            }
            return open(rep, minimalOpenFlagsForDirectories)
        }
        if openedDirfd < 0 {
            let savedErrno = errno
            cleanupTemporaryDirectory(at: replacementDir)
            throw CocoaError.errorWithFilePath(inPath, errno: savedErrno, reading: false, variant: variant)
        }
        let fd: Int32 = basename.withFileSystemRepresentation { basenameRep in
            guard let basenameRep else {
                errno = EINVAL
                return -1
            }
            return openatFileDescriptorProtected(dirfd: openedDirfd, name: basenameRep, flags: O_CREAT | O_EXCL | O_RDWR, options: updatedOptions, mode: permissions)
        }
        if fd < 0 {
            let savedErrno = errno
            close(openedDirfd)
            cleanupTemporaryDirectory(at: replacementDir)
            throw CocoaError.errorWithFilePath(inPath, errno: savedErrno, reading: false, variant: variant)
        }
        return (fd, basename, openedDirfd, replacementDir)
    }
#endif

    let (fd, name) = try createTemporaryFile(destDirfd: destDirfd, destinationPath: destinationPath, inPath: inPath, options: options, permissions: permissions, variant: variant)
    return (fd, name, destDirfd, nil)
#endif // os(WASI)
}

private func write(buffer: RawSpan, toFileDescriptor fd: Int32, path: borrowing some FileSystemRepresentable & ~Copyable, parentProgress: Progress?) throws {
    let count = buffer.byteCount
    parentProgress?.becomeCurrent(withPendingUnitCount: Int64(count))
    defer {
        parentProgress?.resignCurrent()
    }
    
    if count > 0 {
        let result = try writeToFileDescriptorWithProgress(fd, buffer: buffer, reportProgress: parentProgress != nil)
        if result != count {
            throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
        }
    }
    
    if !buffer.isEmpty {
#if os(Windows)
        let hFile: HANDLE? = HANDLE(bitPattern: _get_osfhandle(fd))
        // On Windows, only call _commit if the fd corresponds to an actual file
        // on disk.
        let res: CInt = if let hFile, GetFileType(hFile) == FILE_TYPE_DISK {
            _commit(fd)
        } else {
            0
        }
#else
        let res = fsync(fd)
#endif
        if res < 0 {
            let savedErrno = errno
            let error = CocoaError.errorWithFilePath(path, errno: savedErrno, reading: false)
            #if os(Linux)
            // Linux returns -1 and errno == EINVAL if trying to sync a special file, eg a fifo, character device etc which can be ignored.
            if savedErrno != EINVAL {
                throw error
            }
            #else
            throw error
            #endif
        }
    }
}

// MARK: - Entry points

#if FOUNDATION_FRAMEWORK
extension NSData {
    /// Objective-C entry point to Swift `Data` writing.
    @objc(_writeDataToPath:data:options:reportProgress:error:)
    internal static func _writeData(toPath path: String, data: NSData, options: Data.WritingOptions, reportProgress: Bool) throws {
        try autoreleasepool {
            let span = RawSpan(_unsafeStart: data.bytes, byteCount: data.count)
            try writeToFile(path: path, buffer: span, options: options, attributes: [:], reportProgress: reportProgress)
        }
    }
    
    @objc(_writeDataToPath:data:options:stringEncodingAttributeData:reportProgress:error:)
    internal static func _writeData(toPath path: String, data: NSData, options: Data.WritingOptions, stringEncodingAttributeData: Data, reportProgress: Bool) throws {
        try autoreleasepool {
            let span = RawSpan(_unsafeStart: data.bytes, byteCount: data.count)
            try writeToFile(path: path, buffer: span, options: options, attributes: [NSFileAttributeStringEncoding : stringEncodingAttributeData], reportProgress: reportProgress)
        }
    }
}
#endif

internal func writeToFile(path inPath: borrowing some FileSystemRepresentable & ~Copyable, buffer: RawSpan, options: Data.WritingOptions, attributes: [String : Data] = [:], reportProgress: Bool = false) throws {
#if os(WASI) || os(Emscripten) // `.atomic` is unavailable on WASI/Emscripten
    try writeToFileNoAux(path: inPath, buffer: buffer, options: options, attributes: attributes, reportProgress: reportProgress)
#else
    if options.contains(.atomic) {
        try writeToFileAux(path: inPath, buffer: buffer, options: options, attributes: attributes, reportProgress: reportProgress)
    } else {
        try writeToFileNoAux(path: inPath, buffer: buffer, options: options, attributes: attributes, reportProgress: reportProgress)
    }
#endif
}

/// Create a new file out of `Data` at a path, using atomic writing.
#if os(WASI) || os(Emscripten)
@available(*, unavailable, message: "atomic writing is unavailable in WASI/Emscripten because temporary files are not supported")
#endif
private func writeToFileAux(path inPath: borrowing some FileSystemRepresentable & ~Copyable, buffer: RawSpan, options: Data.WritingOptions, attributes: [String : Data], reportProgress: Bool) throws {
#if os(WASI) || os(Emscripten)
    // `.atomic` is unavailable on WASI/Emscripten
    throw CocoaError(.featureUnsupported)
#else
    assert(options.contains(.atomic))
    
    // TODO: Somehow avoid copying back and forth to a String to hold the path

#if os(Windows)
    var (fd, auxPath, _, temporaryDirectoryPath) = try createProtectedTemporaryFile(destDirfd: -1, destinationPath: inPath.path, inPath: inPath, options: options, permissions: (), variant: "Folder")

    // Cleanup temporary directory
    defer { cleanupTemporaryDirectory(at: temporaryDirectoryPath) }

    guard fd >= 0 else {
        throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
    }

    defer { if fd >= 0 { _close(fd) } }

    let callback = (reportProgress && Progress.current() != nil) ? Progress(totalUnitCount: Int64(buffer.byteCount)) : nil

    do {
        try write(buffer: buffer, toFileDescriptor: fd, path: inPath, parentProgress: callback)
    } catch {
        try auxPath.withNTPathRepresentation { pwszAuxPath in
            _ = DeleteFileW(pwszAuxPath)
        }

        if callback?.isCancelled ?? false {
            throw CocoaError(.userCancelled)
        } else {
            throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
        }
    }

    writeExtendedAttributes(fd: fd, attributes: attributes)

    _close(fd)
    fd = -1

    try auxPath.withNTPathRepresentation { pwszAuxiliaryPath in
        defer { _ = DeleteFileW(pwszAuxiliaryPath) }

        var hFile = CreateFileW(pwszAuxiliaryPath, DELETE,
                                FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                nil, OPEN_EXISTING,
                                FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT,
                                nil)
        if hFile == INVALID_HANDLE_VALUE {
            throw CocoaError.errorWithFilePath(inPath, win32: GetLastError(), reading: false)
        }

        defer {
            switch hFile {
            case INVALID_HANDLE_VALUE:
                break
            default:
                _ = CloseHandle(hFile)
            }
        }

        try inPath.path.withNTPathRepresentation { pwszPath in
            let cchLength = wcslen(pwszPath)
            let cbSize = cchLength * MemoryLayout<WCHAR>.size
            let dwSize = DWORD(MemoryLayout<FILE_RENAME_INFO>.size + cbSize + MemoryLayout<WCHAR>.size)
            try withUnsafeTemporaryAllocation(byteCount: Int(dwSize),
                                              alignment: MemoryLayout<FILE_RENAME_INFO>.alignment) { pBuffer in
                var pInfo = pBuffer.baseAddress?.bindMemory(to: FILE_RENAME_INFO.self, capacity: 1)
                pInfo?.pointee.Flags = FILE_RENAME_FLAG_POSIX_SEMANTICS | FILE_RENAME_FLAG_REPLACE_IF_EXISTS
                pInfo?.pointee.RootDirectory = nil
                pInfo?.pointee.FileNameLength = DWORD(cbSize)
                pBuffer.baseAddress?.advanced(by: MemoryLayout<FILE_RENAME_INFO>.offset(of: \.FileName)!)
                                    .withMemoryRebound(to: WCHAR.self, capacity: cchLength + 1) {
                    wcscpy_s($0, cchLength + 1, pwszPath)
                }

                var renameOk = SetFileInformationByHandle(hFile, FileRenameInfoEx, pInfo, dwSize)

                if !renameOk {
                    var dwError = GetLastError()

                    // FileRenameInfoEx with POSIX_SEMANTICS + REPLACE_IF_EXISTS returns ERROR_ACCESS_DENIED (mapped from NTSTATUS STATUS_CANNOT_DELETE) when the destination has FILE_ATTRIBUTE_READONLY. Clear it on the destination (in line with POSIX semantics) and retry once before falling through.
                    if dwError == ERROR_ACCESS_DENIED {
                        let dwAttributes = GetFileAttributesW(pwszPath)

                        if dwAttributes != INVALID_FILE_ATTRIBUTES
                            && dwAttributes & FILE_ATTRIBUTE_READONLY != 0
                        {
                            // TOCTOU is possible here between GetFileAttributesW and SetFileAttributesW. Only relevant though in the atypical case when SetFileInformationByHandle returns false, where the thread is already on an error path. Hence, skip expensive mitigation and defer to caller.
                            if SetFileAttributesW(pwszPath, dwAttributes & ~FILE_ATTRIBUTE_READONLY) {
                                renameOk = SetFileInformationByHandle(hFile, FileRenameInfoEx, pInfo, dwSize) // Retry

                                if !renameOk {
                                    dwError = GetLastError()
                                }
                            } else {
                                dwError = GetLastError()
                            }
                        }
                    }

                    _ = CloseHandle(hFile)
                    hFile = INVALID_HANDLE_VALUE

                    if renameOk {
                        return
                    }

                    guard dwError == ERROR_NOT_SAME_DEVICE
                        || dwError == ERROR_NOT_SUPPORTED
                        || dwError == ERROR_FILE_SYSTEM_LIMITATION
                        || dwError == ERROR_INVALID_PARAMETER else {
                        throw CocoaError.errorWithFilePath(inPath, win32: dwError, reading: false)
                    }

                    // The move is across volumes or on Volumes that don't support FILE_RENAME_FLAG_POSIX_SEMANTICS, like exFat.
                    guard MoveFileExW(pwszAuxiliaryPath, pwszPath, MOVEFILE_COPY_ALLOWED | MOVEFILE_REPLACE_EXISTING) else {
                        throw CocoaError.errorWithFilePath(inPath, win32: GetLastError(), reading: false)
                    }
                }
            }
        }
    }
#else
    let newPath = inPath.path

    // When capturing the original file's mode, which we'll restore on the new file, we need to pin down the directory that we're obtaining it from to avoid TOCTOU style races. We'll do the same with the temporary directory, then use `renameat`, which will ensure that we place the file in the intended directory even in the face of a concurrent directory symlink swap.
    let parentPath = newPath.deletingLastPathComponent()
    let newBasename = newPath.lastPathComponent
    
    // If the path is just a file name, it's implicitly relative to the CWD, so we'll open "." to pin that directory, as opposed to using AT_FDCWD.
    let parentPathToOpen = parentPath.isEmpty ? "." : parentPath
    let destDirfd: Int32 = try parentPathToOpen.withFileSystemRepresentation { parentFSRep in
        guard let parentFSRep else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let fd = open(parentFSRep, minimalOpenFlagsForDirectories)
        guard fd >= 0 else {
            throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false, variant: "Folder")
        }
        return fd
    }
    defer { close(destDirfd) }

    try newBasename.withFileSystemRepresentation { basenameRep in
        guard let basenameRep else {
            throw CocoaError(.fileWriteInvalidFileName)
        }

        var mode: mode_t?
        var preRenameState = stat()
        let result = fstatat(destDirfd, basenameRep, &preRenameState, AT_SYMLINK_NOFOLLOW)
        if result == 0 {
            mode = mode_t(preRenameState.st_mode) & ~S_IFMT
        } else if (errno != ENOENT) && (errno != ENAMETOOLONG) {
            throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
        }

        // If we captured an existing file's mode, open the temp at the most restrictive mode that still lets us write to it (0o200) so other users' processes can't read or modify the half-written contents; fchmod restores the real mode after rename. For a brand-new file, use 0666 (subject to umask) so open(2)'s usual semantics apply.
        let tempOpenMode: TemporaryFilePermissions = (mode != nil) ? 0o200 : 0o666

        // tempDirfd is the file descriptor of the temporary file's parent directory, which COULD be the same exact file descriptor as destDirfd.
        let (fd, auxName, tempDirfd, temporaryDirectoryPath) = try createProtectedTemporaryFile(destDirfd: destDirfd, destinationPath: newPath, inPath: inPath, options: options, permissions: tempOpenMode, variant: "Folder")

        guard fd >= 0 else {
            let savedErrno = errno
            if tempDirfd != destDirfd { close(tempDirfd) }
            // Cleanup temporary directory
            cleanupTemporaryDirectory(at: temporaryDirectoryPath)
            throw CocoaError.errorWithFilePath(inPath, errno: savedErrno, reading: false)
        }
        
        defer { close(fd) }
        defer { if tempDirfd != destDirfd { close(tempDirfd) } }
        
        let parentProgress = (reportProgress && Progress.current() != nil) ? Progress(totalUnitCount: Int64(buffer.byteCount)) : nil
        
        do {
            try write(buffer: buffer, toFileDescriptor: fd, path: inPath, parentProgress: parentProgress)
        } catch {
            let savedError = errno
            
            auxName.withFileSystemRepresentation { auxNameRep in
                guard let auxNameRep else { return }
                _ = unlinkat(tempDirfd, auxNameRep, 0)
            }
            cleanupTemporaryDirectory(at: temporaryDirectoryPath)
            
            if parentProgress?.isCancelled ?? false {
                throw CocoaError(.userCancelled)
            } else {
                throw CocoaError.errorWithFilePath(inPath, errno: savedError, reading: false)
            }
        }
        
        // Before renaming the file in place, make sure it has the right file mode so that their modification looks atomic
        if let mode {
            fchmod(fd, mode)
        }

        writeExtendedAttributes(fd: fd, attributes: attributes)

        try auxName.withFileSystemRepresentation { auxNameRep in
            guard let auxNameRep else {
                // The aux path is not a valid file name
                throw CocoaError(.fileWriteInvalidFileName)
            }
            
            if renameat(tempDirfd, auxNameRep, destDirfd, basenameRep) != 0 {
                if errno == EINVAL {
                    // rename() fails on DOS file systems if newname already exists.
                    // Makes "atomically" next to meaningless, but...
                    // We try a little harder but this is not thread-safe nor atomic
                    
                    let (fd2, auxName2, tempDirfd2, temporaryDirectoryPath2) = try createProtectedTemporaryFile(destDirfd: destDirfd, destinationPath: newPath, inPath: inPath, options: options, permissions: tempOpenMode)
                    close(fd2)
                    try auxName2.withFileSystemRepresentation { auxName2Rep in
                        guard let auxName2Rep else {
                            // The aux path (2) is not a valid file name
                            throw CocoaError(.fileWriteInvalidFileName)
                        }
                        
                        _ = unlinkat(tempDirfd2, auxName2Rep, 0)
                        
                        if renameat(destDirfd, basenameRep, tempDirfd2, auxName2Rep) != 0 || renameat(tempDirfd, auxNameRep, destDirfd, basenameRep) != 0 {
                            // Swap failed
                            let savedErrno = errno
                            _ = unlinkat(tempDirfd2, auxName2Rep, 0)
                            _ = unlinkat(tempDirfd, auxNameRep, 0)
                            if tempDirfd2 != destDirfd { close(tempDirfd2) }
                            cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                            cleanupTemporaryDirectory(at: temporaryDirectoryPath2)
                            throw CocoaError.errorWithFilePath(inPath, errno: savedErrno, reading: false)
                        }
                        
                        _ = unlinkat(tempDirfd2, auxName2Rep, 0)
                        if tempDirfd2 != destDirfd { close(tempDirfd2) }
                        cleanupTemporaryDirectory(at: temporaryDirectoryPath2)
                    }
                    
                } else if errno == EBUSY {
                    // EBUSY may mean it was an HFS+ file system and something (perhaps another process) still had a reference to resources (vm pages, fd) associated with the file. Try again, non-atomically.
                    _ = unlinkat(tempDirfd, auxNameRep, 0)
                    cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                    
                    // We also throw away any other options, and do not report progress. This may or may not be a bug.
                    return try writeToFile(path: inPath, buffer: buffer, options: [], attributes: attributes, reportProgress: false)
                } else {
                    let savedErrno = errno
                    _ = unlinkat(tempDirfd, auxNameRep, 0)
                    cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                    throw CocoaError.errorWithFilePath(inPath, errno: savedErrno, reading: false)
                }
            }
            
            cleanupTemporaryDirectory(at: temporaryDirectoryPath)
        }
    }
#endif
#endif // os(WASI)
}

/// Create a new file out of `Data` at a path, not using atomic writing.
private func writeToFileNoAux(path inPath: borrowing some FileSystemRepresentable & ~Copyable, buffer: RawSpan, options: Data.WritingOptions, attributes: [String : Data], reportProgress: Bool) throws {
#if !os(WASI) && !os(Emscripten) // `.atomic` is unavailable on WASI/Emscripten
    assert(!options.contains(.atomic))
#endif

#if os(Windows)
    try inPath.path.withNTPathRepresentation { pwszPath in
        let hFile = CreateFileW(pwszPath, GENERIC_WRITE, FILE_SHARE_READ, nil, options.contains(.withoutOverwriting) ? CREATE_NEW : CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nil)
        if hFile == INVALID_HANDLE_VALUE {
            throw CocoaError.errorWithFilePath(inPath, win32: GetLastError(), reading: false)
        }
        let fd = _open_osfhandle(Int(bitPattern: hFile), _O_RDWR | _O_APPEND)
        if fd == -1 {
            throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
        }
        defer { _close(fd) }

        let callback: Progress? = (reportProgress && Progress.current() != nil) ? Progress(totalUnitCount: Int64(buffer.byteCount)) : nil

        do {
            try write(buffer: buffer, toFileDescriptor: fd, path: inPath, parentProgress: callback)
        } catch {
            let savedError = errno
            if callback?.isCancelled ?? false {
                throw CocoaError(.userCancelled)
            } else {
                throw CocoaError.errorWithFilePath(inPath, errno: savedError, reading: false)
            }
        }

        writeExtendedAttributes(fd: fd, attributes: attributes)
    }
#else
    try inPath.withFileSystemRepresentation { pathFileSystemRep in
        guard let pathFileSystemRep else { 
            throw CocoaError(.fileWriteInvalidFileName)
        }
                
        var flags: Int32 = O_WRONLY | O_CREAT | O_TRUNC
        if options.contains(.withoutOverwriting) {
            flags = flags | O_EXCL
        }
            
        let fd = openFileDescriptorProtected(path: pathFileSystemRep, flags: flags, options: options)
        
        guard fd >= 0 else {
            let savedErrno = errno
            throw CocoaError.errorWithFilePath(inPath, errno: savedErrno, reading: false)
        }
        
        defer { close(fd) }
        
        let parentProgress = (reportProgress && Progress.current() != nil) ? Progress(totalUnitCount: Int64(buffer.byteCount)) : nil
        
        do {
            try write(buffer: buffer, toFileDescriptor: fd, path: inPath, parentProgress: parentProgress)
        } catch {
            let savedError = errno

            if parentProgress?.isCancelled ?? false {
                // We could have deleted the partially written data above, but for max binary compatibility we'll only delete if a progress is in use.
                // Ignore any error; it doesn't matter at this point.
                unlink(pathFileSystemRep)
                throw CocoaError(.userCancelled)
            } else {
                throw CocoaError.errorWithFilePath(inPath, errno: savedError, reading: false)
            }
        }
        
        writeExtendedAttributes(fd: fd, attributes: attributes)
    }
#endif
}

private func writeExtendedAttributes(fd: Int32, attributes: [String : Data]) {
    // Write extended attributes
    for (key, value) in attributes {
        value.withUnsafeBytes { valueBuf in
            // Returns non-zero on error, but we ignore them
#if canImport(Darwin)
            _ = fsetxattr(fd, key, valueBuf.baseAddress!, valueBuf.count, 0, 0)
#elseif os(FreeBSD)
            _ = extattr_set_fd(fd, EXTATTR_NAMESPACE_USER, key, valueBuf.baseAddress!, valueBuf.count)
#elseif os(OpenBSD)
            return
#elseif canImport(Glibc) || canImport(Musl)
            _ = fsetxattr(fd, key, valueBuf.baseAddress!, valueBuf.count, 0)
#endif
        }
    }
}
#endif // !NO_FILESYSTEM

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
#if FOUNDATION_FRAMEWORK
    /// Options to control the writing of data to a URL.
    public typealias WritingOptions = NSData.WritingOptions
#else
    
    // This is imported from the ObjC 'option set', which is actually a combination of an option and an enumeration (file protection).
    /// Options to control the writing of data to a URL.
    public struct WritingOptions : OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        /// An option to write data to an auxiliary file first and then replace the original file with the auxiliary file when the write completes.
#if os(WASI) || os(Emscripten)
        @available(*, unavailable, message: "atomic writing is unavailable in WASI/Emscripten because temporary files are not supported")
#endif
        public static let atomic = WritingOptions(rawValue: 1 << 0)
        
        /// An option that attempts to write data to a file and fails with an error if the destination file already exists.
        public static let withoutOverwriting = WritingOptions(rawValue: 1 << 1)
        
        /// An option to not encrypt the file when writing it out.
        public static let noFileProtection = WritingOptions(rawValue: 0x10000000)
        
        /// An option to make the file accessible only while the device is unlocked.
        public static let completeFileProtection = WritingOptions(rawValue: 0x20000000)
        
        /// An option to allow the file to be accessible while the device is unlocked or the file is already open.
        public static let completeFileProtectionUnlessOpen = WritingOptions(rawValue: 0x30000000)
        
        /// An option to allow the file to be accessible after a user first unlocks the device.
        public static let completeFileProtectionUntilFirstUserAuthentication = WritingOptions(rawValue: 0x40000000)
        
        /// An option the system uses when determining the file protection options that the system assigns to the data.
        public static let fileProtectionMask = WritingOptions(rawValue: 0xf0000000)
    }
#endif
    
    /// Writes the contents of the data buffer to a location.
    ///
    /// - parameter url: The location to write the data into.
    /// - parameter options: Options for writing the data. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if there is an error writing to the `URL`.
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
#if !os(WASI) && !os(Emscripten) // `.atomic` is unavailable on WASI/Emscripten
        if options.contains(.withoutOverwriting) && options.contains(.atomic) {
            fatalError("withoutOverwriting is not supported with atomic")
        }
#endif
        
        guard url.isFileURL else {
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
        
#if !NO_FILESYSTEM
        try writeToFile(path: url, buffer: self.bytes, options: options, reportProgress: true)
#else
        throw CocoaError(.featureUnsupported)
#endif
    }
}
