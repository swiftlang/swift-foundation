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

#if os(Windows)

import WinSDK

struct _Win32DirectoryContentsSequence: Sequence {
    final class Iterator: IteratorProtocol {
        struct Element {
            var fileName: String
            var fileNameWithPrefix: String
            var dwFileAttributes: DWORD
        }

        private var hFind: HANDLE?
        private var bValid: Bool = true
        private var ffdData: WIN32_FIND_DATAW = .init()
        private var prefix: String = ""
        private var slash: Bool

        var error: CocoaError?

        init(path: String, appendSlashForDirectory: Bool, prefix: [String]) {
            self.slash = appendSlashForDirectory

            do {
                hFind = try "\(path)\\*".withNTPathRepresentation {
                    // We use `FindFirstFileExW` to avoid the lookup of the short name of the file. We never consult the field and this can speed up the file enumeration.
                    FindFirstFileExW($0, FindExInfoBasic, &self.ffdData, FindExSearchNameMatch, nil, FIND_FIRST_EX_LARGE_FETCH | FIND_FIRST_EX_ON_DISK_ENTRIES_ONLY)
                }
            } catch let error {
                self.error = error as? CocoaError
                return
            }

            // It would be nice to propagate an error from here, but for now the best we can do is return nil from `next`.
            guard let hFind else {
                error = CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                return
            }
            if hFind == INVALID_HANDLE_VALUE {
                error = CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                self.hFind = nil
            } else {
                self.prefix = prefix.compactMap {
                    guard let last = $0.last else { return nil }

                    if ["/", #"\"#].contains(last) {
                        return $0
                    } else {
                        return $0 + #"\"#
                    }
                }.joined()
            }
        }

        deinit {
            _ = FindClose(hFind)
        }

        func next() -> Element? {
            guard let hFind else { return nil }
            guard bValid else { return nil }
            repeat {
                let name = withUnsafeBytes(of: ffdData.cFileName) {
                    String(decodingCString: $0.baseAddress!.assumingMemoryBound(to: WCHAR.self), as: UTF16.self)
                }

                if name == "." || name == ".." {
                    continue
                }

                let prefixed: String =
                    prefix + name + ((slash && ffdData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY) ? #"\"# : "")
                defer { bValid = FindNextFileW(hFind, &ffdData) }
                return Element(fileName: name, fileNameWithPrefix: prefixed, dwFileAttributes: ffdData.dwFileAttributes)
            } while FindNextFileW(hFind, &ffdData)
            bValid = false
            return nil
        }
    }

    let path: String
    let appendSlashForDirectory: Bool
    let prefix: [String]

    init(path: String, appendSlashForDirectory: Bool, prefix: [String] = []) {
        self.path = path
        self.appendSlashForDirectory = appendSlashForDirectory
        self.prefix = prefix
    }

    func makeIterator() -> Iterator {
        Iterator(path: path, appendSlashForDirectory: appendSlashForDirectory, prefix: prefix)
    }
}

#else

#if canImport(Darwin)
import Darwin
#elseif os(Android)
import Android
import posix_filesystem.dirent
#elseif canImport(Glibc)
import Glibc
internal import _FoundationCShims
#elseif os(WASI)
import WASILibc
internal import _FoundationCShims
#endif

// MARK: Directory Iteration

// No FTS support in wasi-libc for now (https://github.com/WebAssembly/wasi-libc/issues/520)
#if !os(WASI)

struct _FTSSequence: Sequence {
    enum Element {
        struct SwiftFTSENT {
            fileprivate let ptr: UnsafeMutablePointer<FTSENT>
            
            var ftsEnt: FTSENT { ptr.pointee }
            var name: String {
                // FTSENT incorrectly represents the `fts_name` property so we must access it directly via the pointer rather than the pointee struct value
                let nameOffset = MemoryLayout<FTSENT>.offset(of: \.fts_name)!
                let len = Int(ptr.pointee.fts_namelen)
                return UnsafeRawPointer(ptr).advanced(by: nameOffset).withMemoryRebound(to: UTF8.CodeUnit.self, capacity: len) { namePtr in
                    String(decoding: UnsafeBufferPointer(start: namePtr, count: len), as: UTF8.self)
                }
            }
            
            init(_ ptr: UnsafeMutablePointer<FTSENT>) {
                self.ptr = ptr
            }
        }
        case entry(SwiftFTSENT)
        case error(errno: Int32, path: String)
    }
    
    final class Iterator: IteratorProtocol {
        enum State {
            case stream(UnsafeMutablePointer<FTS>)
            case error(Int32, String)
            case ended
        }
        var state: State
        var path: UnsafePointer<CChar>
        
        #if canImport(Darwin)
        var lastDeviceInode: dev_t = 0
        var deviceNumbers: [dev_t] = []
        var deviceEntryPoints: [ino_t] = []
        var shouldFilterUnderbars = false
        #endif
        
        init(_ path: UnsafePointer<CChar>, _ opts: Int32) {
            self.path = path
            var statBuf = stat()
            guard lstat(path, &statBuf) == 0 else {
                state = .error(errno, String(cString: path))
                return
            }

            state = [UnsafeMutablePointer(mutating: path), nil].withUnsafeBufferPointer { dirList in
                guard let stream = fts_open(dirList.baseAddress!, opts, nil) else {
                    return .error(errno, String(cString: path))
                }
                return .stream(stream)
            }
        }
        
        deinit {
            _close()
        }
        
        private func _close() {
            if case .stream(let fts) = state {
                fts_close(fts)
            }
            state = .ended
        }
        
        #if canImport(Darwin)
        private func _shouldFilter(_ swiftEnt: Element.SwiftFTSENT) -> Bool {
            let ent = swiftEnt.ftsEnt
            let ftsName = swiftEnt.name
            
            // If we're being requested to iterate a directory that begins with a ._ we should do it.
            if lastDeviceInode == 0 && ftsName.hasPrefix("._") {
                return false
            }
            
            // Instead of asking fts to stat every file just to get the fts_statp->st_dev, we can trust the already-gathered fts_dev info, which is present for at least every FTS_D and FTS_DP entry. 8740034.
            // Don't worry. Even if someone uses FTS_SKIP, FTS always balances FTS_D with FTS_DP.
            
            var currentDev = deviceNumbers.last ?? 0
            if ent.fts_info == FTS_D {
                if deviceNumbers.last != ent.fts_dev {
                    currentDev = ent.fts_dev
                    deviceEntryPoints.append(ent.fts_ino)
                    deviceNumbers.append(ent.fts_dev)
                }
            } else if ent.fts_info == FTS_DP {
                if let lastEntry = deviceEntryPoints.last, lastEntry == ent.fts_ino {
                    deviceEntryPoints.removeLast()
                    deviceNumbers.removeLast()
                }
            }
            
            if currentDev != lastDeviceInode {
                // We've crossed a mount point (i.e. the device is different than the last time we looked).
                var fileSystemInfo = statfs()
                shouldFilterUnderbars = statfs(ent.fts_path, &fileSystemInfo) == 0 && ((fileSystemInfo.f_flags & UInt32(MNT_DOVOLFS)) == 0)
                lastDeviceInode = currentDev
            }
            
            if shouldFilterUnderbars && ftsName.hasPrefix("._") {
                // Don't report ._ files on filesystems that require them.
                return true
            }
            return false
        }
        #else
        private func _shouldFilter(_ swiftEnt: Element.SwiftFTSENT) -> Bool {
            false
        }
        #endif
        
        func next() -> Element? {
            switch state {
            case .stream(let fts):
                if let ent = fts_read(fts) {
                    let swiftEnt = Element.SwiftFTSENT(ent)
                    if _shouldFilter(swiftEnt) {
                        return self.next()
                    } else {
                        return .entry(swiftEnt)
                    }
                } else if errno != 0 {
                    let errNumber = errno
                    _close()
                    return .error(errno: errNumber, path: String(cString: path))
                } else {
                    _close()
                    return nil
                }
            case .error(let errNum, let path):
                state = .ended
                return .error(errno: errNum, path: path)
            case .ended:
                return nil
            }
        }
        
        func skipDescendants(of entry: Element.SwiftFTSENT, skipPostProcessing: Bool = false) {
            guard case .stream(let fts) = state else { return }
            _ = fts_set(fts, entry.ptr, FTS_SKIP)
            if skipPostProcessing {
                assert(Int32(entry.ftsEnt.fts_info) == FTS_D)
                _ = self.next() // Skip the FTS_DP entry for this directory
            }
        }
    }
    
    let path: UnsafePointer<CChar>
    let opts: Int32
    
    init(_ path: UnsafePointer<CChar>, _ opts: Int32) {
        self.path = path
        self.opts = opts
    }
    
    func makeIterator() -> Iterator {
        Iterator(path, opts)
    }
}

enum SubpathElement {
    case entry(String)
    case error(Int32, String)
}

extension Sequence<_FTSSequence.Element> {
    var subpaths: some Sequence<SubpathElement> {
        self.lazy.compactMap {
            switch $0 {
            case .error(let error, let path): return .error(error, path)
            case .entry(let ent):
                switch Int32(ent.ftsEnt.fts_info) {
                // Do the action
                case FTS_D: fallthrough         // Directory being visited in pre-order.
                case FTS_DEFAULT: fallthrough   // Something not defined anywhere else.
                case FTS_F: fallthrough         // Regular file.
                case FTS_NSOK: fallthrough      // No stat(2) information was requested, but that's OK.
                case FTS_SL: fallthrough        // Symlink.
                case FTS_SLNONE:                // Symlink with no target.
                    return .entry(String(cString: ent.ftsEnt.fts_path!))
                    
                // Error returns
                case FTS_DNR: fallthrough   // Directory cannot be read.
                case FTS_ERR: fallthrough   // Some error occurred, but we don't know what.
                case FTS_NS:                // No stat(2) information is available.
                    let path = String(cString: ent.ftsEnt.fts_path!)
                    return .error(ent.ftsEnt.fts_errno, path)
                    
                default: return nil
                }
            }
        }
    }
}

#endif // !os(WASI)

struct _POSIXDirectoryContentsSequence: Sequence {
    #if canImport(Darwin)
    typealias DirectoryEntryPtr = UnsafeMutablePointer<DIR>
    #elseif os(Android) || canImport(Glibc) || os(WASI)
    typealias DirectoryEntryPtr = OpaquePointer
    #endif
    
    final class Iterator: IteratorProtocol {
        func next() -> Element? {
            guard let dirp else { return nil }

            // Loop until we find a value or end
            repeat {
                guard let dent = readdir(dirp) else {
                    closedir(dirp)
                    self.dirp = nil
                    return nil
                }

                #if canImport(Darwin)
                guard dent.pointee.d_namlen != 0 else {
                    continue
                }
                #endif
                guard dent.pointee.d_ino != 0 else {
                    continue
                }
                // Use name
                let fileName: String
                #if os(WASI)
                // Use shim on WASI because wasi-libc defines `d_name` as
                // "flexible array member" which is not supported by
                // ClangImporter yet.
                fileName = String(cString: _platform_shims_dirent_d_name(dent))
                #else
                fileName = withUnsafeBytes(of: &dent.pointee.d_name) { buf in
                    let ptr = buf.baseAddress!.assumingMemoryBound(to: CChar.self)
                    return String(cString: ptr)
                }
                #endif

                if fileName == "." || fileName == ".." || fileName == "._" {
                    continue
                }

                let fullFileName: String
                if appendSlash {
                    var isDirectory = false
                    if dent.pointee.d_type == DT_DIR {
                        isDirectory = true
                    } else if dent.pointee.d_type == DT_UNKNOWN {
                        // We need to do an additional stat on this to see if it's really a directory or not.
                        // This path should be uncommon.
                        var statBuf: stat = stat()
                        let statDir = directoryPath + "/" + fileName
                        if stat(statDir, &statBuf) == 0 {
                            // #define S_ISDIR(m)      (((m) & S_IFMT) == S_IFDIR)
                            if (mode_t(statBuf.st_mode) & S_IFMT) == S_IFDIR {
                                isDirectory = true
                            }
                        }
                    }

                    if isDirectory {
                        fullFileName = prefix + fileName + "/"
                    } else {
                        fullFileName = prefix + fileName
                    }
                } else {
                    fullFileName = prefix + fileName
                }

                return Element(fileName: fileName, fileNameWithPrefix: fullFileName, fileType: dent.pointee.d_type)
            } while true
        }

        struct Element {
            var fileName: String
            var fileNameWithPrefix: String
            var fileType: UInt8
        }

        private var dirp: DirectoryEntryPtr?
        private let directoryPath: String
        private let prefix: String
        private let appendSlash: Bool
        
        var error: CocoaError?

        init(path: String, appendSlashForDirectory: Bool = false, prefix: [String] = []) {
            let dirp = path.withFileSystemRepresentation { ptr -> DirectoryEntryPtr? in
                guard let ptr else { return nil }
                return opendir(ptr)
            }
            if let dirp {
                directoryPath = path
                self.dirp = dirp
                self.appendSlash = appendSlashForDirectory

                // Ensure stuff to prefix list is all /-terminated
                let prefixes: [String] = prefix.compactMap {
                    guard let last = $0.last else {
                        // This string is empty
                        return nil
                    }

                    if last == "/" {
                        return $0
                    } else {
                        return $0 + "/"
                    }
                }

                self.prefix = prefixes.joined()
            } else {
                // It would be nice to propagate an error from here, but for now the best we can do is return nil from `next`.
                directoryPath = ""
                self.prefix = ""
                appendSlash = false
                error = CocoaError.errorWithFilePath(path, errno: errno, reading: true, variant: "Folder")
            }
        }

        deinit {
            if let dirp {
                closedir(dirp)
            }
        }
    }

    let path: String
    let appendSlashForDirectory: Bool
    let prefix: [String]

    init(path: String, appendSlashForDirectory: Bool, prefix: [String] = []) {
        self.path = path
        self.appendSlashForDirectory = appendSlashForDirectory
        self.prefix = prefix
    }

    func makeIterator() -> Iterator {
        Iterator(path: path, appendSlashForDirectory: appendSlashForDirectory, prefix: prefix)
    }
}

#endif
