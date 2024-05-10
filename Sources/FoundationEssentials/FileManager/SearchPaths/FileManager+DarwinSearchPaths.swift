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
internal import Foundation_Private.NSPathUtilities
internal import DarwinPrivate.dirhelper
internal import DarwinPrivate.sysdir
internal import _ForSwiftFoundation
#endif

#if canImport(Darwin)
import Darwin.sysdir

private func foundation_sysdir_start_search_path_enumeration(_ directory: UInt, _ domainMask: UInt) -> sysdir_search_path_enumeration_state {
    #if FOUNDATION_FRAMEWORK
    sysdir_start_search_path_enumeration_private(
        sysdir_search_path_directory_t(UInt32(truncatingIfNeeded: directory)),
        sysdir_search_path_domain_private_mask_t(rawValue: UInt32(truncatingIfNeeded: domainMask))
    )
    #else
    sysdir_start_search_path_enumeration(
        sysdir_search_path_directory_t(UInt32(truncatingIfNeeded: directory)),
        sysdir_search_path_domain_mask_t(rawValue: UInt32(truncatingIfNeeded: domainMask))
    )
    #endif
}

struct _DarwinSearchPathsSequence: Sequence {
    let directory: FileManager.SearchPathDirectory
    let domainMask: FileManager.SearchPathDomainMask
    
    final class Iterator: IteratorProtocol {
        let directory: FileManager.SearchPathDirectory
        let domainMask: FileManager.SearchPathDomainMask
        
        private enum State {
            case sysdir(sysdir_search_path_enumeration_state)
            #if os(macOS) && FOUNDATION_FRAMEWORK
            case special(FileManager.SearchPathDomainMask)
            #endif
        }
        private var state: State
        
        init(directory: FileManager.SearchPathDirectory, domainMask: FileManager.SearchPathDomainMask) {
            self.directory = directory
            self.domainMask = domainMask
            
            switch directory {
            #if os(macOS) && FOUNDATION_FRAMEWORK
            case .trashDirectory:
                state = .special(domainMask.union([.userDomainMask, .localDomainMask]))
            case ._homeDirectory, .applicationScriptsDirectory:
                state = .special(domainMask.union(.userDomainMask))
            #endif
                
            default:
                state = .sysdir(foundation_sysdir_start_search_path_enumeration(directory.rawValue, domainMask.rawValue))
            }
        }
        
        func next() -> String? {
            switch state {
            case .sysdir(let sysdirState):
                return withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { buffer in
                    let newState = sysdir_get_next_search_path_enumeration(sysdirState, buffer.baseAddress!)
                    state = .sysdir(newState)
                    if newState != 0 {
                        return FileManager.default.string(withFileSystemRepresentation: buffer.baseAddress!, length: strlen(buffer.baseAddress!))
                    } else {
                        return nil
                    }
                }
            #if os(macOS) && FOUNDATION_FRAMEWORK
            case .special(var mask):
                defer { state = .special(mask) }
                while let currentMask = mask.firstMask {
                    mask.remove(currentMask)
                    if let result = _specialFind(directory, in: currentMask) {
                        return result
                    }
                }
                return nil
            #endif
            }
        }
        
        #if os(macOS) && FOUNDATION_FRAMEWORK
        private func _specialFindReturn(_ buffer: UnsafeMutableBufferPointer<CChar>) -> String? {
            guard buffer.baseAddress!.pointee != 0 else { return nil }
            
            let path = String(cString: buffer.baseAddress!)
            // strip trailing slashes because NSPathUtilities doesn't return paths with trailing slashes.
            guard let endIndex = path.unicodeScalars.lastIndex(where: { $0 != "/" }) else {
                // It's only slashes, so just return a single slash
                return "/"
            }
            return String(path[...endIndex])
        }
        
        private func _specialFind(_ directory: FileManager.SearchPathDirectory, in mask: FileManager.SearchPathDomainMask) -> String? {
            withUnsafeTemporaryAllocation(of: CChar.self, capacity: FileManager.MAX_PATH_SIZE) { cpath in
                switch (directory, mask)  {
                case (.trashDirectory, .userDomainMask):
                    // get the trash relative to the home directory without checking to see if the directory exists
                    return String.homeDirectoryPath().withFileSystemRepresentation { homePathPtr -> String? in
                        guard let homePathPtr else { return nil }
                        if __user_relative_dirname(geteuid(), DIRHELPER_RELATIVE_TRASH, homePathPtr, cpath.baseAddress!, FileManager.MAX_PATH_SIZE) != nil {
                            var buff = stat()
                            if lstat(cpath.baseAddress!, &buff) == 0 {
                                return _specialFindReturn(cpath)?.abbreviatingWithTildeInPath
                            }
                        }
                        return nil
                    }
                    
                case (.trashDirectory, .localDomainMask):
                    // get the trash on the boot volume without checking to see if the directory exists
                    if __user_relative_dirname(geteuid(), DIRHELPER_RELATIVE_TRASH, "/", cpath.baseAddress!, FileManager.MAX_PATH_SIZE) != nil {
                        var buff = stat()
                        if lstat(cpath.baseAddress!, &buff) == 0 {
                            return _specialFindReturn(cpath)
                        }
                    }
                    return nil
                    
                case (.applicationScriptsDirectory, .userDomainMask):
                    guard let id = _NSCodeSigningIdentifierForCurrentProcess() else {
                        return nil
                    }
                    return "\("~".replacingTildeWithRealHomeDirectory)/Library/Application Scripts/\(id)"
                    
                case (._homeDirectory, .userDomainMask):
                    return "~"
                    
                default:
                    return nil
                }
            }
        }
        #endif
    }
    
    func makeIterator() -> Iterator {
        Iterator(directory: directory, domainMask: domainMask)
    }
}

#if os(macOS) && FOUNDATION_FRAMEWORK
extension String {
    internal var replacingTildeWithRealHomeDirectory: String {
        guard self == "~" || self.hasPrefix("~/") else {
            return self
        }
        var bufSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        if bufSize == -1 {
            bufSize = 4096 // A generous guess.
        }
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: bufSize) { pwBuff in
            var pw: UnsafeMutablePointer<passwd>?
            var pwd = passwd()
            let euid = geteuid()
            let trueUid = euid == 0 ? getuid() : euid
            guard getpwuid_r(trueUid, &pwd, pwBuff.baseAddress!, bufSize, &pw) == 0, let pw else {
                return self
            }
            return String(cString: pw.pointee.pw_dir).appendingPathComponent(String(self.dropFirst()))
        }
    }
}
#endif // os(macOS) && FOUNDATION_FRAMEWORK
#endif // canImport(Darwin)
