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
internal import _ForSwiftFoundation
internal import DarwinPrivate // for VREG
#endif

internal import _CShims

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if !NO_FILESYSTEM

// MARK: - Helpers

private func openFileDescriptorProtected(path: UnsafePointer<CChar>, flags: Int32, options: Data.WritingOptions) -> Int32 {
#if FOUNDATION_FRAMEWORK
    // Use file protection on this platform
    return _NSOpenFileDescriptor_Protected(path, Int(flags), options, 0o666)
#else
    return open(path, flags, 0o666)
#endif
}

private func preferredChunkSizeForFileDescriptor(_ fd: Int32) -> Int? {
#if canImport(Darwin)
    var preferredChunkSize = -1
    var fsinfo = statfs()
    var fileinfo = stat()
    if fstatfs(fd, &fsinfo) != -1 {
        if fstat(fd, &fileinfo) != -1 {
            preferredChunkSize = Int(fileinfo.st_blksize)
        } else {
            logFileIOErrno(errno, at: "fstat")
        }
    } else {
        preferredChunkSize = Int(fsinfo.f_iosize)
    }

    // Make sure we don't return something completely bone-headed, like zero.
    if (preferredChunkSize <= 0) {
        return nil
    }
    
    return preferredChunkSize
#else
    return nil
#endif
}

private func writeToFileDescriptorWithProgress(_ fd: Int32, buffer: UnsafeRawBufferPointer, reportProgress: Bool) throws -> Int {
    // Fetch this once
    let length = buffer.count
    var preferredChunkSize = length
    let localProgress = (reportProgress && Progress.current() != nil) ? Progress(totalUnitCount: Int64(preferredChunkSize)) : nil
    
    if localProgress != nil {
        // To report progress, we have to try writing in smaller chunks than the whole file. Get one that makes sense for this destination.
        if let smarterChunkSize = preferredChunkSizeForFileDescriptor(fd) {
            preferredChunkSize = smarterChunkSize
        }
    }

    var nextRange = buffer.startIndex..<buffer.startIndex.advanced(by: length)
    var numBytesRemaining = length
    while numBytesRemaining > 0 {
        if let localProgress, localProgress.isCancelled {
            throw CocoaError(.userCancelled)
        }
        
        // Don't ever attempt to write more than (2GB - 1 byte). Some platforms will return an error over that amount.
        let numBytesRequested = min(preferredChunkSize, Int(Int32.max))
        let smallestAmountToRead = min(numBytesRequested, numBytesRemaining)
        let upperBound = nextRange.startIndex + smallestAmountToRead
        nextRange = nextRange.startIndex..<upperBound
        var numBytesWritten: Int
        repeat {
            if let localProgress, localProgress.isCancelled {
                throw CocoaError(.userCancelled)
            }
            numBytesWritten = buffer[nextRange].withUnsafeBytes { buf in
                write(fd, buf.baseAddress!, buf.count)
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
                numBytesRemaining -= numBytesWritten
                if let localProgress {
                    localProgress.completedUnitCount = Int64(length - numBytesRemaining)
                }
                // Anytime we write less than actually requested, stop, since the length is considered the "max" for socket calls
                if numBytesWritten < numBytesRequested {
                    break
                }
                
                nextRange = nextRange.startIndex.advanced(by: numBytesWritten)..<buffer.endIndex
            }
        } while numBytesWritten < 0 && errno == EINTR
    }
    
    let bytesWritten = length - numBytesRemaining
    return bytesWritten
}

private func cleanupTemporaryDirectory(at inPath: String?) {
    guard let inPath else { return }
    inPath.withFileSystemRepresentation { pathFileSystemRep in
        guard let pathFileSystemRep else { return }
#if FOUNDATION_FRAMEWORK
        if rmdir(pathFileSystemRep) != 0 {
            // Attempt to use FileManager, ignore error
            try? FileManager.default.removeItem(atPath: inPath)
        }
#else
        _ = rmdir(pathFileSystemRep)
#endif
    }
}

/// Caller is responsible for calling `close` on the `Int32` file descriptor.
private func createTemporaryFile(at destinationPath: String, inPath: PathOrURL, prefix: String, options: Data.WritingOptions) throws -> (Int32, String) {
    var directoryPath = destinationPath
    if !directoryPath.isEmpty && directoryPath.last! != "/" {
        directoryPath.append("/")
    }
    
    let pidString = String(getpid(), radix: 16, uppercase: true)
    let template = directoryPath + prefix + pidString + ".XXXXXX"
    var count = 0
    let maxCount = 7
    repeat {
        let result = try template.withMutableFileSystemRepresentation { templateFileSystemRep -> (Int32, String)? in
            guard let templateFileSystemRep else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            
            // The warning diligently tells us we shouldn't be using mktemp() because blindly opening the returned path opens us up to a TOCTOU race. However, in this case, we're being careful by doing O_CREAT|O_EXCL and repeating, just like the implementation of mkstemp.
            // Furthermore, we can't compatibly switch to mkstemp() until we have the ability to set fchmod correctly, which requires the ability to query the current umask, which we don't have. (22033100)
            guard mktemp(templateFileSystemRep) != nil else {
                throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
            }
            
            let flags: Int32 = O_CREAT | O_EXCL | O_RDWR
            let fd = openFileDescriptorProtected(path: templateFileSystemRep, flags: flags, options: options)
            if fd >= 0 {
                // Got a good fd
                return (fd, String(cString: templateFileSystemRep))
            }
            
            // If the file exists, we repeat. Otherwise throw the error.
            if errno != EEXIST {
                throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
            }

            // Try again
            return nil
        }
        
        if let result {
            return result
        } else {
            count += 1
            if count > maxCount {
                // Prevent an infinite loop; even if the error is obscure
                throw CocoaError(.fileWriteUnknown)
            }
        }
    } while true
}

/// Returns `(file descriptor, temporary file path, temporary directory path)`
/// Caller is responsible for calling `close` on the `Int32` file descriptor and calling `cleanupTemporaryDirectory` on the temporary directory path. The temporary directory path may be nil, if it does not need to be cleaned up.
private func createProtectedTemporaryFile(at destinationPath: String, inPath: PathOrURL, options: Data.WritingOptions) throws -> (Int32, String, String?) {
#if FOUNDATION_FRAMEWORK
    if _foundation_sandbox_check(getpid(), nil) != 0 {
        // Convert the path back into a string
        let url = URL(fileURLWithPath: destinationPath, isDirectory: false)
        let temporaryDirectoryPath = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true).path(percentEncoded: false)
        
        let auxFile = temporaryDirectoryPath.appendingPathComponent(destinationPath.lastPathComponent)
        return try auxFile.withFileSystemRepresentation { auxFileFileSystemRep in
            guard let auxFileFileSystemRep else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            let fd = openFileDescriptorProtected(path: auxFileFileSystemRep, flags: O_CREAT | O_EXCL | O_RDWR, options: options)
            if fd >= 0 {
                return (fd, auxFile, temporaryDirectoryPath)
            } else {
                cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
            }
        }
    }
#endif
    
    let temporaryDirectoryPath = destinationPath.deletingLastPathComponent()
    let (fd, auxFile) = try createTemporaryFile(at: temporaryDirectoryPath, inPath: inPath, prefix: ".dat.nosync", options: options)
    return (fd, auxFile, nil)
}

private func write(buffer: UnsafeRawBufferPointer, toFileDescriptor fd: Int32, path: PathOrURL, parentProgress: Progress?) throws {
    let count = buffer.count
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
        if fsync(fd) < 0 {
            throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
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
            let buffer = UnsafeRawBufferPointer(start: data.bytes, count: data.count)
            try writeToFile(path: .path(path), buffer: buffer, options: options, attributes: [:], reportProgress: reportProgress)
        }
    }
    
    @objc(_writeDataToPath:data:options:stringEncodingAttributeData:reportProgress:error:)
    internal static func _writeData(toPath path: String, data: NSData, options: Data.WritingOptions, stringEncodingAttributeData: Data, reportProgress: Bool) throws {
        try autoreleasepool {
            let buffer = UnsafeRawBufferPointer(start: data.bytes, count: data.count)
            try writeToFile(path: .path(path), buffer: buffer, options: options, attributes: [NSFileAttributeStringEncoding : stringEncodingAttributeData], reportProgress: reportProgress)
        }
    }
}
#endif

internal func writeToFile(path inPath: PathOrURL, data: Data, options: Data.WritingOptions, attributes: [String : Data] = [:], reportProgress: Bool = false) throws {
    try data.withUnsafeBytes { buffer in
        try writeToFile(path: inPath, buffer: buffer, options: options, attributes: attributes, reportProgress: reportProgress)
    }
}

internal func writeToFile(path inPath: PathOrURL, buffer: UnsafeRawBufferPointer, options: Data.WritingOptions, attributes: [String : Data] = [:], reportProgress: Bool = false) throws {
    if options.contains(.atomic) {
        try writeToFileAux(path: inPath, buffer: buffer, options: options, attributes: attributes, reportProgress: reportProgress)
    } else {
        try writeToFileNoAux(path: inPath, buffer: buffer, options: options, attributes: attributes, reportProgress: reportProgress)
    }
}

/// Create a new file out of `Data` at a path, using atomic writing.
private func writeToFileAux(path inPath: PathOrURL, buffer: UnsafeRawBufferPointer, options: Data.WritingOptions, attributes: [String : Data], reportProgress: Bool) throws {
    assert(options.contains(.atomic))
    
    // TODO: Somehow avoid copying back and forth to a String to hold the path

    try inPath.withFileSystemRepresentation { inPathFileSystemRep in
        guard let inPathFileSystemRep else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        
        let fd: Int32
        var mode: mode_t?
        var temporaryDirectoryPath: String?
        var auxPath: String?
        
#if FOUNDATION_FRAMEWORK
        var newPath = inPath.path
        var preRenameAttributes = PreRenameAttributes()
        var attrs = attrlist(bitmapcount: u_short(ATTR_BIT_MAP_COUNT), reserved: 0, commonattr: attrgroup_t(ATTR_CMN_OBJTYPE | ATTR_CMN_ACCESSMASK | ATTR_CMN_FULLPATH), volattr: .init(), dirattr: .init(), fileattr: .init(ATTR_FILE_LINKCOUNT), forkattr: .init())
        let result = getattrlist(inPathFileSystemRep, &attrs, &preRenameAttributes, MemoryLayout<PreRenameAttributes>.size, .init(FSOPT_NOFOLLOW))
        if result == 0 {
            // Use the path from the buffer
            mode = mode_t(preRenameAttributes.mode)
            if preRenameAttributes.fileType == VREG.rawValue && !(preRenameAttributes.nlink > 1) {
                // Copy the contents of the getattrlist buffer for the string into a Swift String
                withUnsafePointer(to: preRenameAttributes.fullPathBuf) { ptrToTuple in
                    // The length of the string is passed back to us in the same struct as the C string itself
                    // n.b. Length includes the null-termination byte. Use this size for the buffer.
                    let length = Int(preRenameAttributes.fullPathAttr.attr_length)
                    ptrToTuple.withMemoryRebound(to: CChar.self, capacity: length) { pointer in
                        newPath = String(cString: pointer)
                    }
                }
            }
        } else if (errno != ENOENT) && (errno != ENAMETOOLONG) {
            throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
        }
#else
        let newPath = inPath.path
#endif
        
        do {
            (fd, auxPath, temporaryDirectoryPath) = try createProtectedTemporaryFile(at: newPath, inPath: inPath, options: options)
        } catch {
            if let cocoaError = error as? CocoaError {
                // Extract code and userInfo, then re-create it with an additional userInfo key.
                let code = cocoaError.code
                var userInfo = cocoaError.userInfo
                userInfo[NSUserStringVariantErrorKey] = "Folder"
                
                throw CocoaError(code, userInfo: userInfo)
            } else {
                // These should all be CocoaErrors, but just in case we re-throw the original one here.
                throw error
            }
        }
        
        guard fd >= 0 else {
            let savedErrno = errno
            // Cleanup temporary directory
            cleanupTemporaryDirectory(at: temporaryDirectoryPath)
            throw CocoaError.errorWithFilePath(inPath, errno: savedErrno, reading: false)
        }
        
        defer { close(fd) }
        
        let parentProgress = (reportProgress && Progress.current() != nil) ? Progress(totalUnitCount: Int64(buffer.count)) : nil
        
        do {
            try write(buffer: buffer, toFileDescriptor: fd, path: inPath, parentProgress: parentProgress)
        } catch {
            let savedError = errno
            
            if let auxPath {
                auxPath.withFileSystemRepresentation { pathFileSystemRep in
                    guard let pathFileSystemRep else { return }
                    unlink(pathFileSystemRep)
                }
            }
            cleanupTemporaryDirectory(at: temporaryDirectoryPath)
            
            if parentProgress?.isCancelled ?? false {
                throw CocoaError(.userCancelled)
            } else {
                throw CocoaError.errorWithFilePath(inPath, errno: savedError, reading: false)
            }
        }
        
        writeExtendedAttributes(fd: fd, attributes: attributes)
        
        guard let auxPath else {
            // We're done now
            return
        }

        try auxPath.withFileSystemRepresentation { auxPathFileSystemRep in
            guard let auxPathFileSystemRep else {
                // The aux path is not a valid file name
                throw CocoaError(.fileWriteInvalidFileName)
            }
            
            try newPath.withFileSystemRepresentation { newPathFileSystemRep in
                guard let newPathFileSystemRep else {
                    // The new path is not a valid file name
                    throw CocoaError(.fileWriteInvalidFileName)
                }
                
                if rename(auxPathFileSystemRep, newPathFileSystemRep) != 0 {
                    if errno == EINVAL {
                        // rename() fails on DOS file systems if newname already exists.
                        // Makes "atomically" next to meaningless, but...
                        // We try a little harder but this is not thread-safe nor atomic
                        
                        let (fd2, auxPath2, temporaryDirectoryPath2) = try createProtectedTemporaryFile(at: newPath, inPath: inPath, options: options)
                        close(fd2)
                        try auxPath2.withFileSystemRepresentation { auxPath2FileSystemRep in
                            guard let auxPath2FileSystemRep else {
                                // The aux path (2) is not a valid file name
                                throw CocoaError(.fileWriteInvalidFileName)
                            }
                            
                            unlink(auxPath2FileSystemRep)
                            
                            if rename(newPathFileSystemRep, auxPath2FileSystemRep) != 0 || rename(auxPathFileSystemRep, newPathFileSystemRep) != 0 {
                                // Swap failed
                                unlink(auxPath2FileSystemRep)
                                unlink(auxPathFileSystemRep)
                                cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                                cleanupTemporaryDirectory(at: temporaryDirectoryPath2)
                                throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
                            }
                            
                            unlink(auxPath2FileSystemRep)
                            cleanupTemporaryDirectory(at: temporaryDirectoryPath2)
                        }
                        
                    } else if errno == EBUSY {
                        // EBUSY may mean it was an HFS+ file system and something (perhaps another process) still had a reference to resources (vm pages, fd) associated with the file. Try again, non-atomically.
                        unlink(auxPathFileSystemRep)
                        cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                        
                        // We also throw away any other options, and do not report progress. This may or may not be a bug.
                        return try writeToFile(path: inPath, buffer: buffer, options: [], attributes: attributes, reportProgress: false)
                    } else {
                        unlink(auxPathFileSystemRep)
                        cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                        throw CocoaError.errorWithFilePath(inPath, errno: errno, reading: false)
                    }
                }
                
                cleanupTemporaryDirectory(at: temporaryDirectoryPath)
                
                if let mode {
                    // Try to change the mode if the path has not changed. Do our best, but don't report an error.
#if FOUNDATION_FRAMEWORK
                    var attrs = attrlist(bitmapcount: u_short(ATTR_BIT_MAP_COUNT), reserved: 0, commonattr: attrgroup_t(ATTR_CMN_FULLPATH), volattr: .init(), dirattr: .init(), fileattr: .init(), forkattr: .init())
                    var buffer = FullPathAttributes()
                    let result = fgetattrlist(fd, &attrs, &buffer, MemoryLayout<FullPathAttributes>.size, .init(FSOPT_NOFOLLOW))
                    // Compare the last one to this one
                    if result == 0 {
                        withUnsafePointer(to: buffer.fullPathBuf) { ptrToTuple in
                            let newPathLength = strlen(newPathFileSystemRep) + 1 // Account for the null terminator, because we compare it to fullPathLength
                            let fullPathLength = Int(buffer.fullPathAttr.attr_length) // This includes the null terminator
                            ptrToTuple.withMemoryRebound(to: CChar.self, capacity: fullPathLength) { newNewPathFileSystemRep in
                                if fullPathLength == newPathLength && strncmp(newPathFileSystemRep, newNewPathFileSystemRep, fullPathLength) == 0 {
                                    // Try to change the mode
                                    fchmod(fd, mode)
                                }
                            }
                        }
                    }
#else
                    fchmod(fd, mode)
#endif
                }
            }
        }
    }
}

/// Create a new file out of `Data` at a path, not using atomic writing.
private func writeToFileNoAux(path inPath: PathOrURL, buffer: UnsafeRawBufferPointer, options: Data.WritingOptions, attributes: [String : Data], reportProgress: Bool) throws {
    assert(!options.contains(.atomic))
    
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
        
        let parentProgress = (reportProgress && Progress.current() != nil) ? Progress(totalUnitCount: Int64(buffer.count)) : nil
        
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
}

private func writeExtendedAttributes(fd: Int32, attributes: [String : Data]) {
#if FOUNDATION_FRAMEWORK
    // Write extended attributes
    for (key, value) in attributes {
        value.withUnsafeBytes { valueBuf in
            _ = fsetxattr(fd, key, valueBuf.baseAddress!, valueBuf.count, 0, 0)
            // Returns non-zero on error, but we ignore them
        }
    }
#endif
}

#endif // !NO_FILESYSTEM
