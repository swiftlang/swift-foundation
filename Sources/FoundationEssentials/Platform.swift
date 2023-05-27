//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin

fileprivate let _pageSize = Int(vm_page_size)
#elseif canImport(WinSDK)
import WinSDK
fileprivate var _pageSize: Int {
    var sysInfo: SYSTEM_INFO = SYSTEM_INFO()
    GetSystemInfo(&sysInfo)
    return Int(sysInfo.dwPageSize)
}
#elseif os(WASI)
// WebAssembly defines a fixed page size
fileprivate let _pageSize: Int = 65_536
#else
import Glibc
fileprivate let _pageSize: Int = Int(getpagesize())
#endif // canImport(Darwin)

internal struct Platform {
    static var pageSize: Int = _pageSize

    static func roundDownToMultipleOfPageSize(_ size: Int) -> Int {
        size & ~(self.pageSize - 1)
    }

    static func roundUpToMultipleOfPageSize(_ size: Int) -> Int {
        (self.pageSize + size - 1) & ~(self.pageSize - 1)
    }

    static func copyMemoryPages(_ source: UnsafeRawPointer, _ dest: UnsafeMutableRawPointer, _ length: Int) {
#if canImport(Darwin)
        if vm_copy(
            mach_task_self_,
            vm_address_t(UInt(bitPattern: source)),
            vm_size_t(length),
            vm_address_t(UInt(bitPattern: dest))) != KERN_SUCCESS {
            memmove(dest, source, length)
        }
#else
        memmove(dest, source, length)
#endif // canImport(Darwin)
    }
}
