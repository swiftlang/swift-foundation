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
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import CRT
import WinSDK
internal import _CShims
#endif

extension _FileManagerImpl {
    func createSymbolicLink(
        at url: URL,
        withDestinationURL destURL: URL
    ) throws {
        guard url.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileReadUnsupportedScheme, url)
        }
        
        // If there's no scheme, then this is probably a relative URL.
        if destURL.scheme != nil && !destURL.isFileURL {
            throw CocoaError.errorWithFilePath(.fileWriteUnsupportedScheme, destURL)
        }
        
        let path = url.path
        let destPath = destURL.path
        guard !path.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, url)
        }
        guard !destPath.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, destURL)
        }

        try createSymbolicLink(atPath: path, withDestinationPath: destPath)
    }
    
    func createSymbolicLink(
        atPath path: String,
        withDestinationPath destPath: String
    ) throws {
#if os(Windows)
        var bIsDirectory = false
        _ = fileManager.fileExists(atPath: destPath, isDirectory: &bIsDirectory)

        try path.withNTPathRepresentation { lpSymlinkFileName in
            try destPath.withNTPathRepresentation { lpTargetFileName in
                if CreateSymbolicLinkW(lpSymlinkFileName, lpTargetFileName, SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE | (bIsDirectory ? SYMBOLIC_LINK_FLAG_DIRECTORY : 0)) == 0 {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: false)
                }
            }
        }
#else
        try fileManager.withFileSystemRepresentation(for: path) { srcRep in
            guard let srcRep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, path)
            }
            
            try fileManager.withFileSystemRepresentation(for: destPath) { destRep in
                guard let destRep else {
                    throw CocoaError.errorWithFilePath(.fileReadUnknown, destPath)
                }
                
                if symlink(destRep, srcRep) != 0 {
                    throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                }
            }
        }
#endif
    }
    
    func linkItem(
        at srcURL: URL,
        to dstURL: URL
    ) throws {
        guard srcURL.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileReadUnsupportedScheme, srcURL)
        }
        
        guard dstURL.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileWriteUnsupportedScheme, dstURL)
        }
        
        let srcPath = srcURL.path
        let dstPath = dstURL.path
        guard !srcPath.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, srcURL)
        }
        guard !dstPath.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, dstURL)
        }
        
        try linkItem(atPath: srcPath, toPath: dstPath)
    }
    
    func linkItem(
        atPath srcPath: String,
        toPath dstPath: String
    ) throws {
        try _FileOperations.linkFile(srcPath, to: dstPath, with: fileManager)
    }
    
    func destinationOfSymbolicLink(atPath path: String) throws -> String {
#if os(Windows)
        return try path.withNTPathRepresentation {
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            guard GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes) else {
                throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
            }

            guard faAttributes.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT else {
                throw CocoaError.errorWithFilePath(path, win32: ERROR_BAD_ARGUMENTS, reading: true)
            }

            let hFile: HANDLE = CreateFileW($0, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, nil)
            if hFile == INVALID_HANDLE_VALUE {
                throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
            }
            defer { CloseHandle(hFile) }

            return try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: Int(MAXIMUM_REPARSE_DATA_BUFFER_SIZE)) { buffer in
                guard let pBuffer = buffer.baseAddress else {
                    throw CocoaError.errorWithFilePath(path, win32: ERROR_INVALID_DATA, reading: false)
                }

                var dwBytesWritten: DWORD = 0
                guard DeviceIoControl(hFile, FSCTL_GET_REPARSE_POINT, nil, 0, pBuffer, DWORD(buffer.count), &dwBytesWritten, nil) else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                }
                // Ensure that we have enough data.
                guard dwBytesWritten == MAXIMUM_REPARSE_DATA_BUFFER_SIZE else {
                    throw CocoaError.errorWithFilePath(path, win32: ERROR_INVALID_DATA, reading: false)
                }

                return try pBuffer.withMemoryRebound(to: REPARSE_DATA_BUFFER.self, capacity: 1) { pRDB in
                    let destination: String
                    switch pRDB.pointee.ReparseTag {
                    case CUnsignedLong(IO_REPARSE_TAG_SYMLINK):
                        let SubstituteNameOffset = pRDB.pointee.SymbolicLinkReparseBuffer.SubstituteNameOffset
                        let SubstituteNameLength = pRDB.pointee.SymbolicLinkReparseBuffer.SubstituteNameLength
                        destination = try withUnsafePointer(to: &pRDB.pointee.SymbolicLinkReparseBuffer.PathBuffer) {
                            let pBuffer = UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)
                            let data: Data = Data(bytes: pBuffer.advanced(by: Int(SubstituteNameOffset)), count: Int(SubstituteNameLength))
                            guard let destination = String(data: data, encoding: .utf16LittleEndian) else {
                                throw CocoaError.errorWithFilePath(path, win32: ERROR_INVALID_DATA, reading: false)
                            }
                            return destination
                        }
                        break
                    case CUnsignedLong(IO_REPARSE_TAG_MOUNT_POINT):
                        let SubstituteNameOffset = pRDB.pointee.MountPointReparseBuffer.SubstituteNameOffset
                        let SubstituteNameLength = pRDB.pointee.MountPointReparseBuffer.SubstituteNameLength
                        destination = try withUnsafePointer(to: &pRDB.pointee.MountPointReparseBuffer.PathBuffer) {
                            let pBuffer = UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)
                            let data: Data = Data(bytes: pBuffer.advanced(by: Int(SubstituteNameOffset)), count: Int(SubstituteNameLength))
                            guard let destination = String(data: data, encoding: .utf16LittleEndian) else {
                                throw CocoaError.errorWithFilePath(path, win32: ERROR_INVALID_DATA, reading: false)
                            }
                            return destination
                        }
                        break
                    default:
                        throw CocoaError.errorWithFilePath(path, win32: ERROR_BAD_ARGUMENTS, reading: true)
                    }

                    // Canonicalize the NT object manager path to the DOS style
                    // path. Unfortunately, there is no nice API which can allow us
                    // to do this in a guaranteed way.
                    if destination.hasPrefix("\\??\\") {
                        return String(destination.dropFirst(4))
                    }
                    return destination
                }
            }
        }
#else
        try fileManager.withFileSystemRepresentation(for: path) { rep in
            guard let rep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, path)
            }
            
            return try withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { buffer in
                let charsReturned = readlink(rep, buffer.baseAddress!, FileManager.MAX_PATH_SIZE)
                guard charsReturned >= 0 else {
                    throw CocoaError.errorWithFilePath(path, errno: errno, reading: true)
                }
                
                return fileManager.string(withFileSystemRepresentation: buffer.baseAddress!, length: charsReturned)
            }
        }
#endif
    }
}
