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

internal struct _FileManagerImpl {
    weak var _manager: FileManager?
    weak var delegate: FileManagerDelegate?
    
    var fileManager: FileManager {
        guard let _manager else {
            fatalError("_FileManagerImpl called without a valid reference to a FileManager")
        }
        return _manager
    }
    
    var safeDelegate: FileManagerDelegate? {
#if FOUNDATION_FRAMEWORK
        fileManager._safeDelegate() as? FileManagerDelegate
#else
        self.delegate
#endif
    }
    
    init() {}
    
    #if FOUNDATION_FRAMEWORK
    func displayName(atPath path: String) -> String {
        // We lie to filePath:directoryHint: to avoid the extra stat. Since this URL isn't used as a base URL for another URL, it shouldn't make any difference.
        let url = URL(filePath: path, directoryHint: .notDirectory)
        
        if let storedName = try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName {
            return storedName
        }
        
        return path.lastPathComponent.replacing(":", with: "/")
    }
    #endif
    
    func contents(atPath path: String) -> Data? {
        try? Data(contentsOfFile: path)
    }
    
    func contentsEqual(
        atPath path: String,
        andPath other: String
    ) -> Bool {
        func _openFD(_ path: UnsafePointer<CChar>) -> Int32? {
            var statBuf = stat()
            let fd = open(path, 0, 0)
            guard fd >= 0 else { return nil }
            if fstat(fd, &statBuf) < 0 || statBuf.st_mode & S_IFMT == S_IFDIR {
                close(fd)
                return nil
            }
            return fd
        }
        
        // compares contents in efficient manner
        // note that symlinks are not traversed!
        guard let myInfo = fileManager._fileStat(path), let otherInfo = fileManager._fileStat(other) else {
            return false
        }
        
        /* check for being hard links */
        if myInfo.st_dev == otherInfo.st_dev && myInfo.st_ino == otherInfo.st_ino {
            return true
        }
        
        /* check for being same type */
        if myInfo.st_mode & S_IFMT != otherInfo.st_mode & S_IFMT {
            return false
        }
        
        if myInfo.isSpecial {
            return myInfo.st_rdev == otherInfo.st_rdev // different inodes aiming at same device
        }
        
        if myInfo.isRegular {
            if myInfo.st_size != otherInfo.st_size {
                return false
            }
            return fileManager.withFileSystemRepresentation(for: path) { pathPtr in
                guard let pathPtr, let fd1 = _openFD(pathPtr) else { return false }
                defer { close(fd1) }
                return fileManager.withFileSystemRepresentation(for: other) { otherPtr in
                    guard let otherPtr, let fd2 = _openFD(otherPtr) else { return false }
                    defer { close(fd2) }
                    #if canImport(Darwin)
                    _ = fcntl(fd1, F_NOCACHE, 1)
                    _ = fcntl(fd2, F_NOCACHE, 1)
                    #endif
                    let quantum = 8 * 1024
                    return withUnsafeTemporaryAllocation(of: CChar.self, capacity: quantum) { buf1 in
                        buf1.initialize(repeating: 0)
                        defer { buf1.deinitialize() }
                        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: quantum) { buf2 in
                            buf2.initialize(repeating: 0)
                            defer { buf2.deinitialize() }
                            var readBytes = 0
                            while true {
                                readBytes = read(fd1, buf1.baseAddress!, quantum)
                                guard readBytes > 0 else { break }
                                if read(fd2, buf2.baseAddress!, quantum) != readBytes {
                                    return false
                                }
                                if !buf1.elementsEqual(buf2) {
                                    return false
                                }
                            }
                            if readBytes < -1 { return false }
                            return true
                        }
                    }
                }
            }
        } else if myInfo.isSymbolicLink {
            return (try? fileManager.destinationOfSymbolicLink(atPath: path) == fileManager.destinationOfSymbolicLink(atPath: other)) ?? false
        } else if myInfo.isDirectory {
            guard let myContents = try? fileManager.contentsOfDirectory(atPath: path),
                  let otherContents = try? Set(fileManager.contentsOfDirectory(atPath: other)),
                  myContents.count == otherContents.count else { return false }
            for item in myContents {
                guard otherContents.contains(item) else { return false }
                let myItemPath = "\(path)/\(item)"
                let otherItemPath = "\(other)/\(item)"
                // Ok to call to self here because it's the same function
                if !self.contentsEqual(atPath: myItemPath, andPath: otherItemPath) {
                    return false
                }
            }
            return true
        }
        
        fatalError("Unknown file type 0x\(String(myInfo.st_mode, radix: 16)) for file \(path)")
    }
    
    func fileSystemRepresentation(withPath path: String) -> UnsafePointer<CChar>? {
        path.withFileSystemRepresentation { ptr -> UnsafePointer<CChar>? in
            guard let ptr else {
                return nil
            }
            
            let len = strlen(ptr) + 1
            let newPtr = UnsafeMutablePointer<CChar>.allocate(capacity: len)
            memcpy(newPtr, ptr, len)
            return UnsafePointer(newPtr)
        }
    }
    
    // SPI
    func getFileSystemRepresentation(_ buffer: UnsafeMutablePointer<CChar>, maxLength: UInt, with path: String) -> Bool {
        guard !path.isEmpty else {
            return false
        }
        return path.withFileSystemRepresentation { ptr in
            guard let ptr else {
                return false
            }
            let lengthOfData = strlen(ptr) + 1
            guard lengthOfData <= maxLength else {
                return false
            }
            
            memcpy(buffer, ptr, lengthOfData)
            return true
        }
    }
    
    func string(
        withFileSystemRepresentation str: UnsafePointer<CChar>,
        length len: Int
    ) -> String {
        UnsafeBufferPointer(start: str, count: len).withMemoryRebound(to: UInt8.self) { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }
}

extension FileManager {
    #if FOUNDATION_FRAMEWORK
    @nonobjc
    func withFileSystemRepresentation<R>(for path: String, _ body: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        var selfType: Any.Type { Self.self }
        if selfType != FileManager.self {
            // Subclasses can override getFileSystemRepresentation. Continue to call into that function to preserve subclassing behavior
            return try withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { buffer in
               guard self.getFileSystemRepresentation(buffer.baseAddress!, maxLength: FileManager.MAX_PATH_SIZE, withPath: path) else {
                   return try body(nil)
               }
               return try body(buffer.baseAddress)
            }
        }
        // We don't have a subclass, so we can call this directly to avoid the temp allocation + copy
        return try path.withFileSystemRepresentation(body)
    }
    #endif
    
    @nonobjc
    func _fileStat(_ path: String) -> stat? {
        let result = self.withFileSystemRepresentation(for: path) { rep -> stat? in
            var s = stat()
            guard let rep, lstat(rep, &s) == 0 else {
                return nil
            }
            return s
        }
        
        guard let result else { return nil }
        return result
    }
    
    @nonobjc
    static var MAX_PATH_SIZE: Int { 1026 }
}
