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
    }
}
