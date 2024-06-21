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

#if os(Windows)
@usableFromInline let calloc = ucrt.calloc
@usableFromInline let malloc = ucrt.malloc
@usableFromInline let free = ucrt.free
@usableFromInline let memset = ucrt.memset
@usableFromInline let memcpy = ucrt.memcpy
@usableFromInline let memcmp = ucrt.memcmp
#endif
#if canImport(Glibc)
@usableFromInline let calloc = Glibc.calloc
@usableFromInline let malloc = Glibc.malloc
@usableFromInline let free = Glibc.free
@usableFromInline let memset = Glibc.memset
@usableFromInline let memcpy = Glibc.memcpy
@usableFromInline let memcmp = Glibc.memcmp
#elseif canImport(Musl)
@usableFromInline let calloc = Musl.calloc
@usableFromInline let malloc = Musl.malloc
@usableFromInline let free = Musl.free
@usableFromInline let memset = Musl.memset
@usableFromInline let memcpy = Musl.memcpy
@usableFromInline let memcmp = Musl.memcmp
#elseif canImport(WASILibc)
@usableFromInline let calloc = WASILibc.calloc
@usableFromInline let malloc = WASILibc.malloc
@usableFromInline let free = WASILibc.free
@usableFromInline let memset = WASILibc.memset
@usableFromInline let memcpy = WASILibc.memcpy
@usableFromInline let memcmp = WASILibc.memcmp
#endif

internal import _FoundationCShims

#if canImport(Darwin)
import Darwin

internal func __DataInvokeDeallocatorVirtualMemory(_ mem: UnsafeMutableRawPointer, _ length: Int) {
    guard vm_deallocate(
        _platform_mach_task_self(),
        vm_address_t(UInt(bitPattern: mem)),
        vm_size_t(length)) == ERR_SUCCESS else {
        fatalError("*** __DataInvokeDeallocatorVirtualMemory(\(mem), \(length)) failed")
    }
}
#endif

#if !canImport(Darwin)
@inlinable // This is @inlinable as trivially computable.
internal func malloc_good_size(_ size: Int) -> Int {
    return size
}
#endif

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#endif

#if os(Windows)
import func WinSDK.UnmapViewOfFile
#endif

internal func __DataInvokeDeallocatorUnmap(_ mem: UnsafeMutableRawPointer, _ length: Int) {
#if os(Windows)
    _ = UnmapViewOfFile(mem)
#elseif canImport(C)
    free(mem)
#else
    munmap(mem, length)
#endif
}

internal func __DataInvokeDeallocatorFree(_ mem: UnsafeMutableRawPointer, _ length: Int) {
    free(mem)
}


@_alwaysEmitIntoClient
internal func _withStackOrHeapBuffer(capacity: Int, _ body: (UnsafeMutableBufferPointer<UInt8>) -> Void) {
    guard capacity > 0 else {
        body(UnsafeMutableBufferPointer(start: nil, count: 0))
        return
    }
    typealias InlineBuffer = ( // 32 bytes
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )
    let inlineCount = MemoryLayout<InlineBuffer>.size
    if capacity <= inlineCount {
        var buffer: InlineBuffer = (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
        withUnsafeMutableBytes(of: &buffer) { buffer in
            assert(buffer.count == inlineCount)
            buffer.withMemoryRebound(to: UInt8.self) {
                body(UnsafeMutableBufferPointer(start: $0.baseAddress, count: capacity))
            }
        }
        return
    }

    let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: capacity)
    defer { buffer.deallocate() }
    body(buffer)
}

// Underlying storage representation for medium and large data.
// Inlinability strategy: methods from here should not inline into InlineSlice or LargeSlice unless trivial.
// NOTE: older overlays called this class _DataStorage. The two must
// coexist without a conflicting ObjC class name, so it was renamed.
// The old name must not be used in the new runtime.
@usableFromInline
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
internal final class __DataStorage : @unchecked Sendable {
    @usableFromInline static let maxSize = Int.max >> 1
    @usableFromInline static let vmOpsThreshold = Platform.pageSize * 4

#if !FOUNDATION_FRAMEWORK
    static func allocate(_ size: Int, _ clear: Bool) -> UnsafeMutableRawPointer? {
        if clear {
            return calloc(1, size)
        } else {
            return malloc(size)
        }
    }

    static func reallocate(_ ptr: UnsafeMutableRawPointer, _ newSize: Int) -> UnsafeMutableRawPointer? {
        return realloc(ptr, newSize);
    }
#endif // !FOUNDATION_FRAMEWORK

    @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
    static func move(_ dest_: UnsafeMutableRawPointer, _ source_: UnsafeRawPointer?, _ num_: Int) {
        var dest = dest_
        var source = source_
        var num = num_
        if __DataStorage.vmOpsThreshold <= num && ((unsafeBitCast(source, to: Int.self) | Int(bitPattern: dest)) & (Platform.pageSize - 1)) == 0 {
            let pages = Platform.roundDownToMultipleOfPageSize(num)
            Platform.copyMemoryPages(source!, dest, pages)
            source = source!.advanced(by: pages)
            dest = dest.advanced(by: pages)
            num -= pages
        }
        if num > 0 {
            memmove(dest, source!, num)
        }
    }

    @inlinable // This is @inlinable as trivially forwarding, and does not escape the _DataStorage boundary layer.
    static func shouldAllocateCleared(_ size: Int) -> Bool {
        return (size > (128 * 1024))
    }

    @usableFromInline var _bytes: UnsafeMutableRawPointer?
    @usableFromInline var _length: Int
    @usableFromInline var _capacity: Int
    @usableFromInline var _offset: Int
    @usableFromInline var _deallocator: ((UnsafeMutableRawPointer, Int) -> Void)?
    @usableFromInline var _needToZero: Bool

    @inlinable // This is @inlinable as trivially computable.
    var bytes: UnsafeRawPointer? {
        return UnsafeRawPointer(_bytes)?.advanced(by: -_offset)
    }

    @inlinable // This is @inlinable despite escaping the _DataStorage boundary layer because it is generic and trivially forwarding.
    @discardableResult
    func withUnsafeBytes<Result>(in range: Range<Int>, apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
        return try apply(UnsafeRawBufferPointer(start: _bytes?.advanced(by: range.lowerBound - _offset), count: Swift.min(range.upperBound - range.lowerBound, _length)))
    }
    
    @inlinable // This is @inlinable despite escaping the _DataStorage boundary layer because it is generic and trivially forwarding.
    @discardableResult
    func withUnsafeMutableBytes<Result>(in range: Range<Int>, apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
        return try apply(UnsafeMutableRawBufferPointer(start: _bytes!.advanced(by:range.lowerBound - _offset), count: Swift.min(range.upperBound - range.lowerBound, _length)))
    }

    @inlinable // This is @inlinable as trivially computable.
    var mutableBytes: UnsafeMutableRawPointer? {
        return _bytes?.advanced(by: -_offset)
    }

    @inlinable // This is @inlinable as trivially computable.
    var capacity: Int {
        return _capacity
    }

    @inlinable // This is @inlinable as trivially computable.
    var length: Int {
        get {
            return _length
        }
        set {
            setLength(newValue)
        }
    }

    @inlinable // This is inlinable as trivially computable.
    var isExternallyOwned: Bool {
        // all __DataStorages will have some sort of capacity, because empty cases hit the .empty enum _Representation
        // anything with 0 capacity means that we have not allocated this pointer and consequently mutation is not ours to make.
        return _capacity == 0
    }

    @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
    func ensureUniqueBufferReference(growingTo newLength: Int = 0, clear: Bool = false) {
        guard isExternallyOwned || newLength > _capacity else { return }

        if newLength == 0 {
            if isExternallyOwned {
                let newCapacity = malloc_good_size(_length)
                let newBytes = __DataStorage.allocate(newCapacity, false)
                __DataStorage.move(newBytes!, _bytes!, _length)
                _freeBytes()
                _bytes = newBytes
                _capacity = newCapacity
                _needToZero = false
            }
        } else if isExternallyOwned {
            let newCapacity = malloc_good_size(newLength)
            let newBytes = __DataStorage.allocate(newCapacity, clear)
            if let bytes = _bytes {
                __DataStorage.move(newBytes!, bytes, _length)
            }
            _freeBytes()
            _bytes = newBytes
            _capacity = newCapacity
            _length = newLength
            _needToZero = true
        } else {
            let cap = _capacity
            var additionalCapacity = (newLength >> (__DataStorage.vmOpsThreshold <= newLength ? 2 : 1))
            if Int.max - additionalCapacity < newLength {
                additionalCapacity = 0
            }
            var newCapacity = malloc_good_size(Swift.max(cap, newLength + additionalCapacity))
            let origLength = _length
            var allocateCleared = clear && __DataStorage.shouldAllocateCleared(newCapacity)
            var newBytes: UnsafeMutableRawPointer? = nil
            if _bytes == nil {
                newBytes = __DataStorage.allocate(newCapacity, allocateCleared)
                if newBytes == nil {
                    /* Try again with minimum length */
                    allocateCleared = clear && __DataStorage.shouldAllocateCleared(newLength)
                    newBytes = __DataStorage.allocate(newLength, allocateCleared)
                }
            } else {
                let tryCalloc = (origLength == 0 || (newLength / origLength) >= 4)
                if allocateCleared && tryCalloc {
                    newBytes = __DataStorage.allocate(newCapacity, true)
                    if let newBytes = newBytes {
                        __DataStorage.move(newBytes, _bytes!, origLength)
                        _freeBytes()
                    }
                }
                /* Where calloc/memmove/free fails, realloc might succeed */
                if newBytes == nil {
                    allocateCleared = false
                    if _deallocator != nil {
                        newBytes = __DataStorage.allocate(newCapacity, true)
                        if let newBytes = newBytes {
                            __DataStorage.move(newBytes, _bytes!, origLength)
                            _freeBytes()
                        }
                    } else {
                        newBytes = __DataStorage.reallocate(_bytes!, newCapacity)
                    }
                }
                /* Try again with minimum length */
                if newBytes == nil {
                    newCapacity = malloc_good_size(newLength)
                    allocateCleared = clear && __DataStorage.shouldAllocateCleared(newCapacity)
                    if allocateCleared && tryCalloc {
                        newBytes = __DataStorage.allocate(newCapacity, true)
                        if let newBytes = newBytes {
                            __DataStorage.move(newBytes, _bytes!, origLength)
                            _freeBytes()
                        }
                    }
                    if newBytes == nil {
                        allocateCleared = false
                        newBytes = __DataStorage.reallocate(_bytes!, newCapacity)
                    }
                }
            }

            if newBytes == nil {
                /* Could not allocate bytes */
                // At this point if the allocation cannot occur the process is likely out of memory
                // and Bad-Things™ are going to happen anyhow
                fatalError("unable to allocate memory for length (\(newLength))")
            }

            if origLength < newLength && clear && !allocateCleared {
                _ = memset(newBytes!.advanced(by: origLength), 0, newLength - origLength)
            }

            /* _length set by caller */
            _bytes = newBytes
            _capacity = newCapacity
            /* Realloc/memset doesn't zero out the entire capacity, so we must be safe and clear next time we grow the length */
            _needToZero = !allocateCleared
        }
    }

    @inlinable // This is @inlinable as it does not escape the _DataStorage boundary layer.
    func _freeBytes() {
        if let bytes = _bytes {
            if let dealloc = _deallocator {
                dealloc(bytes, length)
            } else {
                free(bytes)
            }
        }
        _deallocator = nil
    }

    @inlinable // This is @inlinable despite escaping the _DataStorage boundary layer because it is trivially computed.
    func enumerateBytes(in range: Range<Int>, _ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Data.Index, _ stop: inout Bool) -> Void) {
        var stopv: Bool = false
        let buffer = UnsafeRawBufferPointer(start: _bytes, count: Swift.min(range.upperBound - range.lowerBound, _length))
        buffer.withMemoryRebound(to: UInt8.self) { block($0, 0, &stopv) }
    }

    @inlinable // This is @inlinable as it does not escape the _DataStorage boundary layer.
    func setLength(_ length: Int) {
        let origLength = _length
        let newLength = length
        if _capacity < newLength || _bytes == nil {
            ensureUniqueBufferReference(growingTo: newLength, clear: true)
        } else if origLength < newLength && _needToZero {
            _ = memset(_bytes! + origLength, 0, newLength - origLength)
        } else if newLength < origLength {
            _needToZero = true
        }
        _length = newLength
    }

    @inlinable // This is @inlinable as it does not escape the _DataStorage boundary layer.
    func append(_ bytes: UnsafeRawPointer, length: Int) {
        precondition(length >= 0, "Length of appending bytes must not be negative")
        let origLength = _length
        let newLength = origLength + length
        if _capacity < newLength || _bytes == nil {
            ensureUniqueBufferReference(growingTo: newLength, clear: false)
        }
        _length = newLength
        __DataStorage.move(_bytes!.advanced(by: origLength), bytes, length)
    }

    @inlinable // This is @inlinable despite escaping the __DataStorage boundary layer because it is trivially computed.
    func get(_ index: Int) -> UInt8 {
        // index must have already been validated by the caller
        return _bytes!.load(fromByteOffset: index - _offset, as: UInt8.self)
    }

    @inlinable // This is @inlinable despite escaping the _DataStorage boundary layer because it is trivially computed.
    func set(_ index: Int, to value: UInt8) {
        // index must have already been validated by the caller
        ensureUniqueBufferReference()
        _bytes!.storeBytes(of: value, toByteOffset: index - _offset, as: UInt8.self)
    }

    @inlinable // This is @inlinable despite escaping the _DataStorage boundary layer because it is trivially computed.
    func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
        let offsetPointer = UnsafeRawBufferPointer(start: _bytes?.advanced(by: range.lowerBound - _offset), count: Swift.min(range.upperBound - range.lowerBound, _length))
        UnsafeMutableRawBufferPointer(start: pointer, count: range.upperBound - range.lowerBound).copyMemory(from: offsetPointer)
    }

    #if FOUNDATION_FRAMEWORK
    @available(FoundationPreview 0.1, *)
    #endif
    @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
    func replaceBytes(in range_: Range<Int>, with replacementBytes: UnsafeRawPointer?, length replacementLength: Int) {
        let range = range_.lowerBound - _offset ..< range_.upperBound - _offset
        let currentLength = _length
        let resultingLength = currentLength - (range.upperBound - range.lowerBound) + replacementLength
        let shift = resultingLength - currentLength
        let mutableBytes: UnsafeMutableRawPointer
        if resultingLength > currentLength {
            ensureUniqueBufferReference(growingTo: resultingLength)
            _length = resultingLength
        } else {
            ensureUniqueBufferReference()
        }
        mutableBytes = _bytes!
        /* shift the trailing bytes */
        let start = range.lowerBound
        let length = range.upperBound - range.lowerBound
        if shift != 0 {
            memmove(mutableBytes + start + replacementLength, mutableBytes + start + length, currentLength - start - length)
        }
        if replacementLength != 0 {
            if let replacementBytes = replacementBytes {
                memmove(mutableBytes + start, replacementBytes, replacementLength)
            } else {
                _ = memset(mutableBytes + start, 0, replacementLength)
            }
        }

        if resultingLength < currentLength {
            setLength(resultingLength)
        }
    }

    @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
    func resetBytes(in range_: Range<Int>) {
        let range = range_.lowerBound - _offset ..< range_.upperBound - _offset
        if range.upperBound - range.lowerBound == 0 { return }
        if _length < range.upperBound {
            if _capacity <= range.upperBound {
                ensureUniqueBufferReference(growingTo: range.upperBound, clear: false)
            }
            _length = range.upperBound
        } else {
            ensureUniqueBufferReference()
        }
        _ = memset(_bytes!.advanced(by: range.lowerBound), 0, range.upperBound - range.lowerBound)
    }

    @usableFromInline // This is not @inlinable as a non-trivial, non-convenience initializer.
    init(length: Int) {
        precondition(length < __DataStorage.maxSize)
        var capacity = (length < 1024 * 1024 * 1024) ? length + (length >> 2) : length
        if __DataStorage.vmOpsThreshold <= capacity {
            capacity = Platform.roundUpToMultipleOfPageSize(capacity)
        }

        let clear = __DataStorage.shouldAllocateCleared(length)
        _bytes = __DataStorage.allocate(capacity, clear)!
        _capacity = capacity
        _needToZero = !clear
        _length = 0
        _offset = 0
        setLength(length)
    }

    @usableFromInline // This is not @inlinable as a non-convenience initializer.
    init(capacity capacity_: Int = 0) {
        var capacity = capacity_
        precondition(capacity < __DataStorage.maxSize)
        if __DataStorage.vmOpsThreshold <= capacity {
            capacity = Platform.roundUpToMultipleOfPageSize(capacity)
        }
        _length = 0
        _bytes = __DataStorage.allocate(capacity, false)!
        _capacity = capacity
        _needToZero = true
        _offset = 0
    }

    @usableFromInline // This is not @inlinable as a non-convenience initializer.
    init(bytes: UnsafeRawPointer?, length: Int) {
        precondition(length < __DataStorage.maxSize)
        _offset = 0
        if length == 0 {
            _capacity = 0
            _length = 0
            _needToZero = false
            _bytes = nil
        } else if __DataStorage.vmOpsThreshold <= length {
            _capacity = length
            _length = length
            _needToZero = true
            _bytes = __DataStorage.allocate(length, false)!
            __DataStorage.move(_bytes!, bytes, length)
        } else {
            var capacity = length
            if __DataStorage.vmOpsThreshold <= capacity {
                capacity = Platform.roundUpToMultipleOfPageSize(capacity)
            }
            _length = length
            _bytes = __DataStorage.allocate(capacity, false)!
            _capacity = capacity
            _needToZero = true
            __DataStorage.move(_bytes!, bytes, length)
        }
    }

    @usableFromInline // This is not @inlinable as a non-convenience initializer.
    init(bytes: UnsafeMutableRawPointer?, length: Int, copy: Bool, deallocator: ((UnsafeMutableRawPointer, Int) -> Void)?, offset: Int) {
        precondition(length < __DataStorage.maxSize)
        _offset = offset
        if length == 0 {
            _capacity = 0
            _length = 0
            _needToZero = false
            _bytes = nil
            if let dealloc = deallocator,
               let bytes_ = bytes {
                dealloc(bytes_, length)
            }
        } else if !copy {
            _capacity = length
            _length = length
            _needToZero = false
            _bytes = bytes
            _deallocator = deallocator
        } else if __DataStorage.vmOpsThreshold <= length {
            _capacity = length
            _length = length
            _needToZero = true
            _bytes = __DataStorage.allocate(length, false)!
            __DataStorage.move(_bytes!, bytes, length)
            if let dealloc = deallocator {
                dealloc(bytes!, length)
            }
        } else {
            var capacity = length
            if __DataStorage.vmOpsThreshold <= capacity {
                capacity = Platform.roundUpToMultipleOfPageSize(capacity)
            }
            _length = length
            _bytes = __DataStorage.allocate(capacity, false)!
            _capacity = capacity
            _needToZero = true
            __DataStorage.move(_bytes!, bytes, length)
            if let dealloc = deallocator {
                dealloc(bytes!, length)
            }
        }
    }

    @usableFromInline
    init(offset: Int, bytes: UnsafeMutableRawPointer, capacity: Int, needToZero: Bool, length: Int, deallocator: ((UnsafeMutableRawPointer, Int) -> Void)?) {
        _offset = offset
        _bytes = bytes
        _capacity = capacity
        _needToZero = needToZero
        _length = length
        _deallocator = deallocator
    }

    deinit {
        _freeBytes()
    }

    @inlinable // This is @inlinable despite escaping the __DataStorage boundary layer because it is trivially computed.
    func mutableCopy(_ range: Range<Int>) -> __DataStorage {
        return __DataStorage(bytes: _bytes?.advanced(by: range.lowerBound - _offset), length: range.upperBound - range.lowerBound, copy: true, deallocator: nil, offset: range.lowerBound)
    }
}

@frozen
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Data : Equatable, Hashable, RandomAccessCollection, MutableCollection, RangeReplaceableCollection, MutableDataProtocol, ContiguousBytes, Sendable {

    public typealias Index = Int
    public typealias Indices = Range<Int>

    // A small inline buffer of bytes suitable for stack-allocation of small data.
    // Inlinability strategy: everything here should be inlined for direct operation on the stack wherever possible.
    @usableFromInline
    @frozen
    internal struct InlineData : Sendable {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        @usableFromInline typealias Buffer = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                              UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) //len  //enum
        @usableFromInline var bytes: Buffer
#elseif arch(i386) || arch(arm) || arch(arm64_32)
        @usableFromInline typealias Buffer = (UInt8, UInt8, UInt8, UInt8,
                                              UInt8, UInt8) //len  //enum
        @usableFromInline var bytes: Buffer
#else
    #error ("Unsupported architecture: a definition of Buffer needs to be made with N = (MemoryLayout<(Int, Int)>.size - 2) UInt8 members to a tuple")
#endif
        @usableFromInline var length: UInt8

        @inlinable // This is @inlinable as trivially computable.
        static func canStore(count: Int) -> Bool {
            return count <= MemoryLayout<Buffer>.size
        }

        static var maximumCapacity: Int {
            return MemoryLayout<Buffer>.size
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ srcBuffer: UnsafeRawBufferPointer) {
            self.init(count: srcBuffer.count)
            if !srcBuffer.isEmpty {
                Swift.withUnsafeMutableBytes(of: &bytes) { dstBuffer in
                    dstBuffer.baseAddress?.copyMemory(from: srcBuffer.baseAddress!, byteCount: srcBuffer.count)
                }
            }
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(count: Int = 0) {
            assert(count <= MemoryLayout<Buffer>.size)
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
            bytes = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
#elseif arch(i386) || arch(arm) || arch(arm64_32)
            bytes = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
#else
    #error ("Unsupported architecture: initialization for Buffer is required for this architecture")
#endif
            length = UInt8(count)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ slice: InlineSlice, count: Int) {
            self.init(count: count)
            Swift.withUnsafeMutableBytes(of: &bytes) { dstBuffer in
                slice.withUnsafeBytes { srcBuffer in
                    dstBuffer.copyMemory(from: UnsafeRawBufferPointer(start: srcBuffer.baseAddress, count: count))
                }
            }
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ slice: LargeSlice, count: Int) {
            self.init(count: count)
            Swift.withUnsafeMutableBytes(of: &bytes) { dstBuffer in
                slice.withUnsafeBytes { srcBuffer in
                    dstBuffer.copyMemory(from: UnsafeRawBufferPointer(start: srcBuffer.baseAddress, count: count))
                }
            }
        }

        @inlinable // This is @inlinable as trivially computable.
        var capacity: Int {
            return MemoryLayout<Buffer>.size
        }

        @inlinable // This is @inlinable as trivially computable.
        var count: Int {
            get {
                return Int(length)
            }
            set(newValue) {
                assert(newValue <= MemoryLayout<Buffer>.size)
                if newValue > length {
                    resetBytes(in: Int(length) ..< newValue) // Also extends length
                } else {
                    length = UInt8(newValue)
                }
            }
        }

        @inlinable // This is @inlinable as trivially computable.
        var startIndex: Int {
            return 0
        }

        @inlinable // This is @inlinable as trivially computable.
        var endIndex: Int {
            return count
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            let count = Int(length)
            return try Swift.withUnsafeBytes(of: bytes) { (rawBuffer) throws -> Result in
                return try apply(UnsafeRawBufferPointer(start: rawBuffer.baseAddress, count: count))
            }
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        mutating func withUnsafeMutableBytes<Result>(_ apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
            let count = Int(length)
            return try Swift.withUnsafeMutableBytes(of: &bytes) { (rawBuffer) throws -> Result in
                return try apply(UnsafeMutableRawBufferPointer(start: rawBuffer.baseAddress, count: count))
            }
        }

        @inlinable // This is @inlinable as trivially computable.
        mutating func append(byte: UInt8) {
            let count = self.count
            assert(count + 1 <= MemoryLayout<Buffer>.size)
            Swift.withUnsafeMutableBytes(of: &bytes) { $0[count] = byte }
            self.length += 1
        }

        @inlinable // This is @inlinable as trivially computable.
        mutating func append(contentsOf buffer: UnsafeRawBufferPointer) {
            guard !buffer.isEmpty else { return }
            assert(count + buffer.count <= MemoryLayout<Buffer>.size)
            let cnt = count
            _ = Swift.withUnsafeMutableBytes(of: &bytes) { rawBuffer in
                rawBuffer.baseAddress?.advanced(by: cnt).copyMemory(from: buffer.baseAddress!, byteCount: buffer.count)
            }

            length += UInt8(buffer.count)
        }

        @inlinable // This is @inlinable as trivially computable.
        subscript(index: Index) -> UInt8 {
            get {
                assert(index <= MemoryLayout<Buffer>.size)
                precondition(index < length, "index \(index) is out of bounds of 0..<\(length)")
                return Swift.withUnsafeBytes(of: bytes) { rawBuffer -> UInt8 in
                    return rawBuffer[index]
                }
            }
            set(newValue) {
                assert(index <= MemoryLayout<Buffer>.size)
                precondition(index < length, "index \(index) is out of bounds of 0..<\(length)")
                Swift.withUnsafeMutableBytes(of: &bytes) { rawBuffer in
                    rawBuffer[index] = newValue
                }
            }
        }

        @inlinable // This is @inlinable as trivially computable.
        mutating func resetBytes(in range: Range<Index>) {
            assert(range.lowerBound <= MemoryLayout<Buffer>.size)
            assert(range.upperBound <= MemoryLayout<Buffer>.size)
            precondition(range.lowerBound <= length, "index \(range.lowerBound) is out of bounds of 0..<\(length)")
            if length < range.upperBound {
                length = UInt8(range.upperBound)
            }

            let _ = Swift.withUnsafeMutableBytes(of: &bytes) { rawBuffer in
              memset(rawBuffer.baseAddress!.advanced(by: range.lowerBound), 0, range.upperBound - range.lowerBound)
            }
        }

        @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
        mutating func replaceSubrange(_ subrange: Range<Index>, with replacementBytes: UnsafeRawPointer?, count replacementLength: Int) {
            assert(subrange.lowerBound <= MemoryLayout<Buffer>.size)
            assert(subrange.upperBound <= MemoryLayout<Buffer>.size)
            assert(count - (subrange.upperBound - subrange.lowerBound) + replacementLength <= MemoryLayout<Buffer>.size)
            precondition(subrange.lowerBound <= length, "index \(subrange.lowerBound) is out of bounds of 0..<\(length)")
            precondition(subrange.upperBound <= length, "index \(subrange.upperBound) is out of bounds of 0..<\(length)")
            let currentLength = count
            let resultingLength = currentLength - (subrange.upperBound - subrange.lowerBound) + replacementLength
            let shift = resultingLength - currentLength
            Swift.withUnsafeMutableBytes(of: &bytes) { mutableBytes in
                /* shift the trailing bytes */
                let start = subrange.lowerBound
                let length = subrange.upperBound - subrange.lowerBound
                if shift != 0 {
                    memmove(mutableBytes.baseAddress!.advanced(by: start + replacementLength), mutableBytes.baseAddress!.advanced(by: start + length), currentLength - start - length)
                }
                if replacementLength != 0 {
                    memmove(mutableBytes.baseAddress!.advanced(by: start), replacementBytes!, replacementLength)
                }
            }
            length = UInt8(resultingLength)
        }

        @inlinable // This is @inlinable as trivially computable.
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            precondition(startIndex <= range.lowerBound, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= range.upperBound, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.upperBound <= endIndex, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")

            Swift.withUnsafeBytes(of: bytes) {
                let cnt = Swift.min($0.count, range.upperBound - range.lowerBound)
                guard cnt > 0 else { return }
                pointer.copyMemory(from: $0.baseAddress!.advanced(by: range.lowerBound), byteCount: cnt)
            }
        }

        @inline(__always) // This should always be inlined into _Representation.hash(into:).
        func hash(into hasher: inout Hasher) {
            // **NOTE**: this uses `count` (an Int) and NOT `length` (a UInt8)
            //           Despite having the same value, they hash differently. InlineSlice and LargeSlice both use `count` (an Int); if you combine the same bytes but with `length` over `count`, you can get a different hash.
            //
            // This affects slices, which are InlineSlice and not InlineData:
            //
            //   let d = Data([0xFF, 0xFF])                // InlineData
            //   let s = Data([0, 0xFF, 0xFF]).dropFirst() // InlineSlice
            //   assert(s == d)
            //   assert(s.hashValue == d.hashValue)
            hasher.combine(count)

            Swift.withUnsafeBytes(of: bytes) {
                // We have access to the full byte buffer here, but not all of it is meaningfully used (bytes past self.length may be garbage).
                let bytes = UnsafeRawBufferPointer(start: $0.baseAddress, count: self.count)
                hasher.combine(bytes: bytes)
            }
        }
    }

#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
    @usableFromInline internal typealias HalfInt = Int32
#elseif arch(i386) || arch(arm) || arch(arm64_32)
    @usableFromInline internal typealias HalfInt = Int16
#else
    #error ("Unsupported architecture: a definition of half of the pointer sized Int needs to be defined for this architecture")
#endif

    // A buffer of bytes too large to fit in an InlineData, but still small enough to fit a storage pointer + range in two words.
    // Inlinability strategy: everything here should be easily inlinable as large _DataStorage methods should not inline into here.
    @usableFromInline
    @frozen
    internal struct InlineSlice : Sendable {
        // ***WARNING***
        // These ivars are specifically laid out so that they cause the enum _Representation to be 16 bytes on 64 bit platforms. This means we _MUST_ have the class type thing last
        @usableFromInline var slice: Range<HalfInt>
        @usableFromInline var storage: __DataStorage

        @inlinable // This is @inlinable as trivially computable.
        static func canStore(count: Int) -> Bool {
            return count < HalfInt.max
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ buffer: UnsafeRawBufferPointer) {
            assert(buffer.count < HalfInt.max)
            self.init(__DataStorage(bytes: buffer.baseAddress, length: buffer.count), count: buffer.count)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(capacity: Int) {
            assert(capacity < HalfInt.max)
            self.init(__DataStorage(capacity: capacity), count: 0)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(count: Int) {
            assert(count < HalfInt.max)
            self.init(__DataStorage(length: count), count: count)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ inline: InlineData) {
            assert(inline.count < HalfInt.max)
            self.init(inline.withUnsafeBytes { return __DataStorage(bytes: $0.baseAddress, length: $0.count) }, count: inline.count)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ inline: InlineData, range: Range<Int>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            self.init(inline.withUnsafeBytes { return __DataStorage(bytes: $0.baseAddress, length: $0.count) }, range: range)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ large: LargeSlice) {
            assert(large.range.lowerBound < HalfInt.max)
            assert(large.range.upperBound < HalfInt.max)
            self.init(large.storage, range: large.range)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ large: LargeSlice, range: Range<Int>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            self.init(large.storage, range: range)
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(_ storage: __DataStorage, count: Int) {
            assert(count < HalfInt.max)
            self.storage = storage
            slice = 0..<HalfInt(count)
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(_ storage: __DataStorage, range: Range<Int>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            self.storage = storage
            slice = HalfInt(range.lowerBound)..<HalfInt(range.upperBound)
        }

        @inlinable // This is @inlinable as trivially computable (and inlining may help avoid retain-release traffic).
        mutating func ensureUniqueReference() {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.mutableCopy(self.range)
            }
        }

        @inlinable // This is @inlinable as trivially computable.
        var startIndex: Int {
            return Int(slice.lowerBound)
        }

        @inlinable // This is @inlinable as trivially computable.
        var endIndex: Int {
            return Int(slice.upperBound)
        }

        @inlinable // This is @inlinable as trivially computable.
        var capacity: Int {
            return storage.capacity
        }

        @inlinable // This is @inlinable as trivially computable (and inlining may help avoid retain-release traffic).
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            ensureUniqueReference()
            // the current capacity can be zero (representing externally owned buffer), and count can be greater than the capacity
            storage.ensureUniqueBufferReference(growingTo: Swift.max(minimumCapacity, count))
        }

        @inlinable // This is @inlinable as trivially computable.
        var count: Int {
            get {
                return Int(slice.upperBound - slice.lowerBound)
            }
            set(newValue) {
                assert(newValue < HalfInt.max)
                ensureUniqueReference()

                let difference = newValue - count
                if difference > 0 {
                    let additionalRange = Int(slice.upperBound) ..< Int(slice.upperBound) + difference
                    storage.resetBytes(in: additionalRange) // Also extends storage length
                } else {
                    storage.length += difference
                }
                slice = slice.lowerBound..<(slice.lowerBound + HalfInt(newValue))
            }
        }

        @inlinable // This is @inlinable as trivially computable.
        var range: Range<Int> {
            get {
                return Int(slice.lowerBound)..<Int(slice.upperBound)
            }
            set(newValue) {
                assert(newValue.lowerBound < HalfInt.max)
                assert(newValue.upperBound < HalfInt.max)
                slice = HalfInt(newValue.lowerBound)..<HalfInt(newValue.upperBound)
            }
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            return try storage.withUnsafeBytes(in: range, apply: apply)
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        mutating func withUnsafeMutableBytes<Result>(_ apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
            ensureUniqueReference()
            return try storage.withUnsafeMutableBytes(in: range, apply: apply)
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func append(contentsOf buffer: UnsafeRawBufferPointer) {
            assert(endIndex + buffer.count < HalfInt.max)
            ensureUniqueReference()
            let upperbound = storage.length + storage._offset
        #if FOUNDATION_FRAMEWORK
            if #available(macOS 14, iOS 17, watchOS 10, tvOS 17, *) {
                storage.replaceBytes(
                    in: range.upperBound ..< upperbound,
                    with: buffer.baseAddress,
                    length: buffer.count)
            } else {
                storage.replaceBytes(
                    in: NSRange(
                        location: range.upperBound,
                        length: storage.length - (range.upperBound - storage._offset)),
                    with: buffer.baseAddress,
                    length: buffer.count)
            }
        #else
            storage.replaceBytes(in: range.upperBound ..< upperbound, with: buffer.baseAddress, length: buffer.count)
        #endif
            slice = slice.lowerBound..<HalfInt(Int(slice.upperBound) + buffer.count)
        }

        @inlinable // This is @inlinable as reasonably small.
        subscript(index: Index) -> UInt8 {
            get {
                assert(index < HalfInt.max)
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                return storage.get(index)
            }
            set(newValue) {
                assert(index < HalfInt.max)
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                ensureUniqueReference()
                storage.set(index, to: newValue)
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func resetBytes(in range: Range<Index>) {
            assert(range.lowerBound < HalfInt.max)
            assert(range.upperBound < HalfInt.max)
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            ensureUniqueReference()
            storage.resetBytes(in: range)
            if slice.upperBound < range.upperBound {
                slice = slice.lowerBound..<HalfInt(range.upperBound)
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func replaceSubrange(_ subrange: Range<Index>, with bytes: UnsafeRawPointer?, count cnt: Int) {
            precondition(startIndex <= subrange.lowerBound, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.lowerBound <= endIndex, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= subrange.upperBound, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.upperBound <= endIndex, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")

            ensureUniqueReference()
            let upper = range.upperBound
        #if FOUNDATION_FRAMEWORK
            if #available(macOS 14, iOS 17, watchOS 10, tvOS 17, *) {
                storage.replaceBytes(in: subrange, with: bytes, length: cnt)
            } else {
                let nsRange = NSRange(
                    location: subrange.lowerBound,
                    length: subrange.upperBound - subrange.lowerBound)
                storage.replaceBytes(in: nsRange, with: bytes, length: cnt)
            }
        #else
            storage.replaceBytes(in: subrange, with: bytes, length: cnt)
        #endif
            let resultingUpper = upper - (subrange.upperBound - subrange.lowerBound) + cnt
            slice = slice.lowerBound..<HalfInt(resultingUpper)
        }

        @inlinable // This is @inlinable as reasonably small.
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            precondition(startIndex <= range.lowerBound, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= range.upperBound, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.upperBound <= endIndex, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            storage.copyBytes(to: pointer, from: range)
        }

        @inline(__always) // This should always be inlined into _Representation.hash(into:).
        func hash(into hasher: inout Hasher) {
            hasher.combine(count)

            // At most, hash the first 80 bytes of this data.
            let range = startIndex ..< Swift.min(startIndex + 80, endIndex)
            storage.withUnsafeBytes(in: range) {
                hasher.combine(bytes: $0)
            }
        }
    }

    // A reference wrapper around a Range<Int> for when the range of a data buffer is too large to whole in a single word.
    // Inlinability strategy: everything should be inlinable as trivial.
    @usableFromInline
    @_fixed_layout
    internal final class RangeReference : @unchecked Sendable {
        @usableFromInline var range: Range<Int>

        @inlinable @inline(__always) // This is @inlinable as trivially forwarding.
        var lowerBound: Int {
            return range.lowerBound
        }

        @inlinable @inline(__always) // This is @inlinable as trivially forwarding.
        var upperBound: Int {
            return range.upperBound
        }

        @inlinable @inline(__always) // This is @inlinable as trivially computable.
        var count: Int {
            return range.upperBound - range.lowerBound
        }

        @inlinable @inline(__always) // This is @inlinable as a trivial initializer.
        init(_ range: Range<Int>) {
            self.range = range
        }
    }

    // A buffer of bytes whose range is too large to fit in a single word. Used alongside a RangeReference to make it fit into _Representation's two-word size.
    // Inlinability strategy: everything here should be easily inlinable as large _DataStorage methods should not inline into here.
    @usableFromInline
    @frozen
    internal struct LargeSlice : Sendable {
        // ***WARNING***
        // These ivars are specifically laid out so that they cause the enum _Representation to be 16 bytes on 64 bit platforms. This means we _MUST_ have the class type thing last
        @usableFromInline var slice: RangeReference
        @usableFromInline var storage: __DataStorage

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ buffer: UnsafeRawBufferPointer) {
            self.init(__DataStorage(bytes: buffer.baseAddress, length: buffer.count), count: buffer.count)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(capacity: Int) {
            self.init(__DataStorage(capacity: capacity), count: 0)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(count: Int) {
            self.init(__DataStorage(length: count), count: count)
        }

        @inlinable // This is @inlinable as a convenience initializer.
        init(_ inline: InlineData) {
            let storage = inline.withUnsafeBytes { return __DataStorage(bytes: $0.baseAddress, length: $0.count) }
            self.init(storage, count: inline.count)
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(_ slice: InlineSlice) {
            self.storage = slice.storage
            self.slice = RangeReference(slice.range)
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(_ storage: __DataStorage, count: Int) {
            self.storage = storage
            self.slice = RangeReference(0..<count)
        }

        @inlinable // This is @inlinable as trivially computable (and inlining may help avoid retain-release traffic).
        mutating func ensureUniqueReference() {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.mutableCopy(range)
            }
            if !isKnownUniquelyReferenced(&slice) {
                slice = RangeReference(range)
            }
        }

        @inlinable // This is @inlinable as trivially forwarding.
        var startIndex: Int {
            return slice.range.lowerBound
        }

        @inlinable // This is @inlinable as trivially forwarding.
        var endIndex: Int {
          return slice.range.upperBound
        }

        @inlinable // This is @inlinable as trivially forwarding.
        var capacity: Int {
            return storage.capacity
        }

        @inlinable // This is @inlinable as trivially computable.
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            ensureUniqueReference()
            // the current capacity can be zero (representing externally owned buffer), and count can be greater than the capacity
            storage.ensureUniqueBufferReference(growingTo: Swift.max(minimumCapacity, count))
        }

        @inlinable // This is @inlinable as trivially computable.
        var count: Int {
            get {
                return slice.count
            }
            set(newValue) {
                ensureUniqueReference()
                let difference = newValue - count
                if difference > 0 {
                    let additionalRange = Int(slice.upperBound) ..< Int(slice.upperBound) + difference
                    storage.resetBytes(in: additionalRange) // Already sets the length
                } else {
                    storage.length += difference
                }
                slice.range = slice.range.lowerBound..<(slice.range.lowerBound + newValue)
            }
        }

        @inlinable // This is @inlinable as it is trivially forwarding.
        var range: Range<Int> {
            return slice.range
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            return try storage.withUnsafeBytes(in: range, apply: apply)
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        mutating func withUnsafeMutableBytes<Result>(_ apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
            ensureUniqueReference()
            return try storage.withUnsafeMutableBytes(in: range, apply: apply)
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func append(contentsOf buffer: UnsafeRawBufferPointer) {
            ensureUniqueReference()
            let upperbound = storage.length + storage._offset
        #if FOUNDATION_FRAMEWORK
            if #available(macOS 14, iOS 17, watchOS 10, tvOS 17, *) {
                storage.replaceBytes(
                    in: range.upperBound ..< upperbound,
                    with: buffer.baseAddress,
                    length: buffer.count)
            } else {
                storage.replaceBytes(
                    in: NSRange(
                        location: range.upperBound,
                        length: storage.length - (range.upperBound - storage._offset)),
                    with: buffer.baseAddress,
                    length: buffer.count)
            }
        #else
            storage.replaceBytes(in: range.upperBound ..< upperbound, with: buffer.baseAddress, length: buffer.count)
        #endif
            slice.range = slice.range.lowerBound..<slice.range.upperBound + buffer.count
        }

        @inlinable // This is @inlinable as trivially computable.
        subscript(index: Index) -> UInt8 {
            get {
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                return storage.get(index)
            }
            set(newValue) {
                precondition(startIndex <= index, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                precondition(index < endIndex, "index \(index) is out of bounds of \(startIndex)..<\(endIndex)")
                ensureUniqueReference()
                storage.set(index, to: newValue)
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func resetBytes(in range: Range<Int>) {
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            ensureUniqueReference()
            storage.resetBytes(in: range)
            if slice.range.upperBound < range.upperBound {
                slice.range = slice.range.lowerBound..<range.upperBound
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func replaceSubrange(_ subrange: Range<Index>, with bytes: UnsafeRawPointer?, count cnt: Int) {
            precondition(startIndex <= subrange.lowerBound, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.lowerBound <= endIndex, "index \(subrange.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= subrange.upperBound, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(subrange.upperBound <= endIndex, "index \(subrange.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")

            ensureUniqueReference()
            let upper = range.upperBound
        #if FOUNDATION_FRAMEWORK
            if #available(macOS 14, iOS 17, watchOS 10, tvOS 17, *) {
                storage.replaceBytes(in: subrange, with: bytes, length: cnt)
            } else {
                let nsRange = NSRange(
                    location: subrange.lowerBound,
                    length: subrange.upperBound - subrange.lowerBound)
                storage.replaceBytes(in: nsRange, with: bytes, length: cnt)
            }
        #else
            storage.replaceBytes(in: subrange, with: bytes, length: cnt)
        #endif
            let resultingUpper = upper - (subrange.upperBound - subrange.lowerBound) + cnt
            slice.range = slice.range.lowerBound..<resultingUpper
        }

        @inlinable // This is @inlinable as reasonably small.
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            precondition(startIndex <= range.lowerBound, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(startIndex <= range.upperBound, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            precondition(range.upperBound <= endIndex, "index \(range.upperBound) is out of bounds of \(startIndex)..<\(endIndex)")
            storage.copyBytes(to: pointer, from: range)
        }

        @inline(__always) // This should always be inlined into _Representation.hash(into:).
        func hash(into hasher: inout Hasher) {
            hasher.combine(count)

            // Hash at most the first 80 bytes of this data.
            let range = startIndex ..< Swift.min(startIndex + 80, endIndex)
            storage.withUnsafeBytes(in: range) {
                hasher.combine(bytes: $0)
            }
        }
    }

    // The actual storage for Data's various representations.
    // Inlinability strategy: almost everything should be inlinable as forwarding the underlying implementations. (Inlining can also help avoid retain-release traffic around pulling values out of enums.)
    @usableFromInline
    @frozen
    internal enum _Representation : Sendable {
        case empty
        case inline(InlineData)
        case slice(InlineSlice)
        case large(LargeSlice)

        @inlinable // This is @inlinable as a trivial initializer.
        init(_ buffer: UnsafeRawBufferPointer) {
            if buffer.isEmpty {
                self = .empty
            } else if InlineData.canStore(count: buffer.count) {
                self = .inline(InlineData(buffer))
            } else if InlineSlice.canStore(count: buffer.count) {
                self = .slice(InlineSlice(buffer))
            } else {
                self = .large(LargeSlice(buffer))
            }
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(_ buffer: UnsafeRawBufferPointer, owner: AnyObject) {
            if buffer.isEmpty {
                self = .empty
            } else if InlineData.canStore(count: buffer.count) {
                self = .inline(InlineData(buffer))
            } else {
                let count = buffer.count
                let storage = __DataStorage(bytes: UnsafeMutableRawPointer(mutating: buffer.baseAddress), length: count, copy: false, deallocator: { _, _ in
                    _fixLifetime(owner)
                }, offset: 0)
                if InlineSlice.canStore(count: count) {
                    self = .slice(InlineSlice(storage, count: count))
                } else {
                    self = .large(LargeSlice(storage, count: count))
                }
            }
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(capacity: Int) {
            if capacity == 0 {
                self = .empty
            } else if InlineData.canStore(count: capacity) {
                self = .inline(InlineData())
            } else if InlineSlice.canStore(count: capacity) {
                self = .slice(InlineSlice(capacity: capacity))
            } else {
                self = .large(LargeSlice(capacity: capacity))
            }
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(count: Int) {
            if count == 0 {
                self = .empty
            } else if InlineData.canStore(count: count) {
                self = .inline(InlineData(count: count))
            } else if InlineSlice.canStore(count: count) {
                self = .slice(InlineSlice(count: count))
            } else {
                self = .large(LargeSlice(count: count))
            }
        }

        @inlinable // This is @inlinable as a trivial initializer.
        init(_ storage: __DataStorage, count: Int) {
            if count == 0 {
                self = .empty
            } else if InlineData.canStore(count: count) {
                self = .inline(storage.withUnsafeBytes(in: 0..<count) { InlineData($0) })
            } else if InlineSlice.canStore(count: count) {
                self = .slice(InlineSlice(storage, count: count))
            } else {
                self = .large(LargeSlice(storage, count: count))
            }
        }

        @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            guard minimumCapacity > 0 else { return }
            switch self {
            case .empty:
                if InlineData.canStore(count: minimumCapacity) {
                    self = .inline(InlineData())
                } else if InlineSlice.canStore(count: minimumCapacity) {
                    self = .slice(InlineSlice(capacity: minimumCapacity))
                } else {
                    self = .large(LargeSlice(capacity: minimumCapacity))
                }
            case .inline(let inline):
                guard minimumCapacity > inline.capacity else { return }
                // we know we are going to be heap promoted
                if InlineSlice.canStore(count: minimumCapacity) {
                    var slice = InlineSlice(inline)
                    slice.reserveCapacity(minimumCapacity)
                    self = .slice(slice)
                } else {
                    var slice = LargeSlice(inline)
                    slice.reserveCapacity(minimumCapacity)
                    self = .large(slice)
                }
            case .slice(var slice):
                guard minimumCapacity > slice.capacity else { return }
                if InlineSlice.canStore(count: minimumCapacity) {
                    self = .empty
                    slice.reserveCapacity(minimumCapacity)
                    self = .slice(slice)
                } else {
                    var large = LargeSlice(slice)
                    large.reserveCapacity(minimumCapacity)
                    self = .large(large)
                }
            case .large(var slice):
                guard minimumCapacity > slice.capacity else { return }
                self = .empty
                slice.reserveCapacity(minimumCapacity)
                self = .large(slice)
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        var count: Int {
            get {
                switch self {
                case .empty: return 0
                case .inline(let inline): return inline.count
                case .slice(let slice): return slice.count
                case .large(let slice): return slice.count
                }
            }
            set(newValue) {
                // HACK: The definition of this inline function takes an inout reference to self, giving the optimizer a unique referencing guarantee.
                //       This allows us to avoid excessive retain-release traffic around modifying enum values, and inlining the function then avoids the additional frame.
                @inline(__always)
                func apply(_ representation: inout _Representation, _ newValue: Int) -> _Representation? {
                    switch representation {
                    case .empty:
                        if newValue == 0 {
                            return nil
                        } else if InlineData.canStore(count: newValue) {
                            return .inline(InlineData(count: newValue))
                        } else if InlineSlice.canStore(count: newValue) {
                            return .slice(InlineSlice(count: newValue))
                        } else {
                            return .large(LargeSlice(count: newValue))
                        }
                    case .inline(var inline):
                        if newValue == 0 {
                            return .empty
                        } else if InlineData.canStore(count: newValue) {
                            guard inline.count != newValue else { return nil }
                            inline.count = newValue
                            return .inline(inline)
                        } else if InlineSlice.canStore(count: newValue) {
                            var slice = InlineSlice(inline)
                            slice.count = newValue
                            return .slice(slice)
                        } else {
                            var slice = LargeSlice(inline)
                            slice.count = newValue
                            return .large(slice)
                        }
                    case .slice(var slice):
                        if newValue == 0 && slice.startIndex == 0 {
                            return .empty
                        } else if slice.startIndex == 0 && InlineData.canStore(count: newValue) {
                            return .inline(InlineData(slice, count: newValue))
                        } else if InlineSlice.canStore(count: newValue + slice.startIndex) {
                            guard slice.count != newValue else { return nil }
                            representation = .empty // TODO: remove this when mgottesman lands optimizations
                            slice.count = newValue
                            return .slice(slice)
                        } else {
                            var newSlice = LargeSlice(slice)
                            newSlice.count = newValue
                            return .large(newSlice)
                        }
                    case .large(var slice):
                        if newValue == 0 && slice.startIndex == 0 {
                            return .empty
                        } else if slice.startIndex == 0 && InlineData.canStore(count: newValue) {
                            return .inline(InlineData(slice, count: newValue))
                        } else {
                            guard slice.count != newValue else { return nil}
                            representation = .empty // TODO: remove this when mgottesman lands optimizations
                            slice.count = newValue
                            return .large(slice)
                        }
                    }
                }

                if let rep = apply(&self, newValue) {
                    self = rep
                }
            }
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            switch self {
            case .empty:
                let empty = InlineData()
                return try empty.withUnsafeBytes(apply)
            case .inline(let inline):
                return try inline.withUnsafeBytes(apply)
            case .slice(let slice):
                return try slice.withUnsafeBytes(apply)
            case .large(let slice):
                return try slice.withUnsafeBytes(apply)
            }
        }

        @inlinable // This is @inlinable as a generic, trivially forwarding function.
        mutating func withUnsafeMutableBytes<Result>(_ apply: (UnsafeMutableRawBufferPointer) throws -> Result) rethrows -> Result {
            switch self {
            case .empty:
                var empty = InlineData()
                return try empty.withUnsafeMutableBytes(apply)
            case .inline(var inline):
                defer { self = .inline(inline) }
                return try inline.withUnsafeMutableBytes(apply)
            case .slice(var slice):
                self = .empty
                defer { self = .slice(slice) }
                return try slice.withUnsafeMutableBytes(apply)
            case .large(var slice):
                self = .empty
                defer { self = .large(slice) }
                return try slice.withUnsafeMutableBytes(apply)
            }
        }

        @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
        func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Index, _ stop: inout Bool) -> Void) {
            switch self {
            case .empty:
                var stop = false
                block(UnsafeBufferPointer<UInt8>(start: nil, count: 0), 0, &stop)
            case .inline(let inline):
                inline.withUnsafeBytes {
                    var stop = false
                    $0.withMemoryRebound(to: UInt8.self) { block($0, 0, &stop) }
                }
            case .slice(let slice):
                slice.storage.enumerateBytes(in: slice.range, block)
            case .large(let slice):
                slice.storage.enumerateBytes(in: slice.range, block)
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func append(contentsOf buffer: UnsafeRawBufferPointer) {
            switch self {
            case .empty:
                self = _Representation(buffer)
            case .inline(var inline):
                if InlineData.canStore(count: inline.count + buffer.count) {
                    inline.append(contentsOf: buffer)
                    self = .inline(inline)
                } else if InlineSlice.canStore(count: inline.count + buffer.count) {
                    var newSlice = InlineSlice(inline)
                    newSlice.append(contentsOf: buffer)
                    self = .slice(newSlice)
                } else {
                    var newSlice = LargeSlice(inline)
                    newSlice.append(contentsOf: buffer)
                    self = .large(newSlice)
                }
            case .slice(var slice):
                if InlineSlice.canStore(count: slice.range.upperBound + buffer.count) {
                    self = .empty
                    defer { self = .slice(slice) }
                    slice.append(contentsOf: buffer)
                } else {
                    self = .empty
                    var newSlice = LargeSlice(slice)
                    newSlice.append(contentsOf: buffer)
                    self = .large(newSlice)
                }
            case .large(var slice):
                self = .empty
                defer { self = .large(slice) }
                slice.append(contentsOf: buffer)
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        mutating func resetBytes(in range: Range<Index>) {
            switch self {
            case .empty:
                if range.upperBound == 0 {
                    self = .empty
                } else if InlineData.canStore(count: range.upperBound) {
                    precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
                    self = .inline(InlineData(count: range.upperBound))
                } else if InlineSlice.canStore(count: range.upperBound) {
                    precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
                    self = .slice(InlineSlice(count: range.upperBound))
                } else {
                    precondition(range.lowerBound <= endIndex, "index \(range.lowerBound) is out of bounds of \(startIndex)..<\(endIndex)")
                    self = .large(LargeSlice(count: range.upperBound))
                }
            case .inline(var inline):
                if inline.count < range.upperBound {
                    if InlineSlice.canStore(count: range.upperBound) {
                        var slice = InlineSlice(inline)
                        slice.resetBytes(in: range)
                        self = .slice(slice)
                    } else {
                        var slice = LargeSlice(inline)
                        slice.resetBytes(in: range)
                        self = .large(slice)
                    }
                } else {
                    inline.resetBytes(in: range)
                    self = .inline(inline)
                }
            case .slice(var slice):
                if InlineSlice.canStore(count: range.upperBound) {
                    self = .empty
                    slice.resetBytes(in: range)
                    self = .slice(slice)
                } else {
                    self = .empty
                    var newSlice = LargeSlice(slice)
                    newSlice.resetBytes(in: range)
                    self = .large(newSlice)
                }
            case .large(var slice):
                self = .empty
                slice.resetBytes(in: range)
                self = .large(slice)
            }
        }

        @usableFromInline // This is not @inlinable as it is a non-trivial, non-generic function.
        mutating func replaceSubrange(_ subrange: Range<Index>, with bytes: UnsafeRawPointer?, count cnt: Int) {
            switch self {
            case .empty:
                precondition(subrange.lowerBound == 0 && subrange.upperBound == 0, "range \(subrange) out of bounds of 0..<0")
                if cnt == 0 {
                    return
                } else if InlineData.canStore(count: cnt) {
                    self = .inline(InlineData(UnsafeRawBufferPointer(start: bytes, count: cnt)))
                } else if InlineSlice.canStore(count: cnt) {
                    self = .slice(InlineSlice(UnsafeRawBufferPointer(start: bytes, count: cnt)))
                } else {
                    self = .large(LargeSlice(UnsafeRawBufferPointer(start: bytes, count: cnt)))
                }
            case .inline(var inline):
                let resultingCount = inline.count + cnt - (subrange.upperBound - subrange.lowerBound)
                if resultingCount == 0 {
                    self = .empty
                } else if InlineData.canStore(count: resultingCount) {
                    inline.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .inline(inline)
                } else if InlineSlice.canStore(count: resultingCount) {
                    var slice = InlineSlice(inline)
                    slice.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .slice(slice)
                } else {
                    var slice = LargeSlice(inline)
                    slice.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .large(slice)
                }
            case .slice(var slice):
                let resultingUpper = slice.endIndex + cnt - (subrange.upperBound - subrange.lowerBound)
                if slice.startIndex == 0 && resultingUpper == 0 {
                    self = .empty
                } else if slice.startIndex == 0 && InlineData.canStore(count: resultingUpper) {
                    self = .empty
                    slice.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .inline(InlineData(slice, count: slice.count))
                } else if InlineSlice.canStore(count: resultingUpper) {
                    self = .empty
                    slice.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .slice(slice)
                } else {
                    self = .empty
                    var newSlice = LargeSlice(slice)
                    newSlice.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .large(newSlice)
                }
            case .large(var slice):
                let resultingUpper = slice.endIndex + cnt - (subrange.upperBound - subrange.lowerBound)
                if slice.startIndex == 0 && resultingUpper == 0 {
                    self = .empty
                } else if slice.startIndex == 0 && InlineData.canStore(count: resultingUpper) {
                    var inline = InlineData(count: resultingUpper)
                    inline.withUnsafeMutableBytes { inlineBuffer in
                        if cnt > 0 {
                            inlineBuffer.baseAddress?.advanced(by: subrange.lowerBound).copyMemory(from: bytes!, byteCount: cnt)
                        }
                        slice.withUnsafeBytes { buffer in
                            if subrange.lowerBound > 0 {
                                inlineBuffer.baseAddress?.copyMemory(from: buffer.baseAddress!, byteCount: subrange.lowerBound)
                            }
                            if subrange.upperBound < resultingUpper {
                                inlineBuffer.baseAddress?.advanced(by: subrange.upperBound).copyMemory(from: buffer.baseAddress!.advanced(by: subrange.upperBound), byteCount: resultingUpper - subrange.upperBound)
                            }
                        }
                    }
                    self = .inline(inline)
                } else if InlineSlice.canStore(count: slice.startIndex) && InlineSlice.canStore(count: resultingUpper) {
                    self = .empty
                    var newSlice = InlineSlice(slice)
                    newSlice.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .slice(newSlice)
                } else {
                    self = .empty
                    slice.replaceSubrange(subrange, with: bytes, count: cnt)
                    self = .large(slice)
                }
            }
        }

        @inlinable // This is @inlinable as trivially forwarding.
        subscript(index: Index) -> UInt8 {
            get {
                switch self {
                case .empty: preconditionFailure("index \(index) out of range of 0")
                case .inline(let inline): return inline[index]
                case .slice(let slice): return slice[index]
                case .large(let slice): return slice[index]
                }
            }
            set(newValue) {
                switch self {
                case .empty: preconditionFailure("index \(index) out of range of 0")
                case .inline(var inline):
                    inline[index] = newValue
                    self = .inline(inline)
                case .slice(var slice):
                    self = .empty
                    slice[index] = newValue
                    self = .slice(slice)
                case .large(var slice):
                    self = .empty
                    slice[index] = newValue
                    self = .large(slice)
                }
            }
        }

        @inlinable // This is @inlinable as reasonably small.
        subscript(bounds: Range<Index>) -> Data {
            get {
                switch self {
                case .empty:
                    precondition(bounds.lowerBound == 0 && (bounds.upperBound - bounds.lowerBound) == 0, "Range \(bounds) out of bounds 0..<0")
                    return Data()
                case .inline(let inline):
                    precondition(bounds.upperBound <= inline.count, "Range \(bounds) out of bounds 0..<\(inline.count)")
                    if bounds.lowerBound == 0 {
                        var newInline = inline
                        newInline.count = bounds.upperBound
                        return Data(representation: .inline(newInline))
                    } else {
                        return Data(representation: .slice(InlineSlice(inline, range: bounds)))
                    }
                case .slice(let slice):
                    precondition(slice.startIndex <= bounds.lowerBound, "Range \(bounds) out of bounds \(slice.range)")
                    precondition(bounds.lowerBound <= slice.endIndex, "Range \(bounds) out of bounds \(slice.range)")
                    precondition(slice.startIndex <= bounds.upperBound, "Range \(bounds) out of bounds \(slice.range)")
                    precondition(bounds.upperBound <= slice.endIndex, "Range \(bounds) out of bounds \(slice.range)")
                    if bounds.lowerBound == 0 && bounds.upperBound == 0 {
                        return Data()
                    } else if bounds.lowerBound == 0 && InlineData.canStore(count: bounds.count) {
                        return Data(representation: .inline(InlineData(slice, count: bounds.count)))
                    } else {
                        var newSlice = slice
                        newSlice.range = bounds
                        return Data(representation: .slice(newSlice))
                    }
                case .large(let slice):
                    precondition(slice.startIndex <= bounds.lowerBound, "Range \(bounds) out of bounds \(slice.range)")
                    precondition(bounds.lowerBound <= slice.endIndex, "Range \(bounds) out of bounds \(slice.range)")
                    precondition(slice.startIndex <= bounds.upperBound, "Range \(bounds) out of bounds \(slice.range)")
                    precondition(bounds.upperBound <= slice.endIndex, "Range \(bounds) out of bounds \(slice.range)")
                    if bounds.lowerBound == 0 && bounds.upperBound == 0 {
                        return Data()
                    } else if bounds.lowerBound == 0 && InlineData.canStore(count: bounds.upperBound) {
                        return Data(representation: .inline(InlineData(slice, count: bounds.upperBound)))
                    } else if InlineSlice.canStore(count: bounds.lowerBound) && InlineSlice.canStore(count: bounds.upperBound) {
                        return Data(representation: .slice(InlineSlice(slice, range: bounds)))
                    } else {
                        var newSlice = slice
                        newSlice.slice = RangeReference(bounds)
                        return Data(representation: .large(newSlice))
                    }
                }
            }
        }

        @inlinable // This is @inlinable as trivially forwarding.
        var startIndex: Int {
            switch self {
            case .empty: return 0
            case .inline: return 0
            case .slice(let slice): return slice.startIndex
            case .large(let slice): return slice.startIndex
            }
        }

        @inlinable // This is @inlinable as trivially forwarding.
        var endIndex: Int {
            switch self {
            case .empty: return 0
            case .inline(let inline): return inline.count
            case .slice(let slice): return slice.endIndex
            case .large(let slice): return slice.endIndex
            }
        }

        @inlinable // This is @inlinable as trivially forwarding.
        func copyBytes(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
            switch self {
            case .empty:
                precondition(range.lowerBound == 0 && range.upperBound == 0, "Range \(range) out of bounds 0..<0")
                return
            case .inline(let inline):
                inline.copyBytes(to: pointer, from: range)
            case .slice(let slice):
                slice.copyBytes(to: pointer, from: range)
            case .large(let slice):
                slice.copyBytes(to: pointer, from: range)
            }
        }

        @inline(__always) // This should always be inlined into Data.hash(into:).
        func hash(into hasher: inout Hasher) {
            switch self {
            case .empty:
                hasher.combine(0)
            case .inline(let inline):
                inline.hash(into: &hasher)
            case .slice(let slice):
                slice.hash(into: &hasher)
            case .large(let large):
                large.hash(into: &hasher)
            }
        }
    }

    @usableFromInline internal var _representation: _Representation

    // A standard or custom deallocator for `Data`.
    ///
    /// When creating a `Data` with the no-copy initializer, you may specify a `Data.Deallocator` to customize the behavior of how the backing store is deallocated.
    @_nonSendable
    public enum Deallocator {
        /// Use a virtual memory deallocator.
#if canImport(Darwin)
        case virtualMemory
#endif // canImport(Darwin)

        /// Use `munmap`.
        case unmap

        /// Use `free`.
        case free

        /// Do nothing upon deallocation.
        case none

        /// A custom deallocator.
        case custom((UnsafeMutableRawPointer, Int) -> Void)

        @usableFromInline internal var _deallocator : ((UnsafeMutableRawPointer, Int) -> Void) {
            switch self {
            case .unmap:
                return { __DataInvokeDeallocatorUnmap($0, $1) }
            case .free:
                return { __DataInvokeDeallocatorFree($0, $1) }
            case .none:
                return { _, _ in }
            case .custom(let b):
                return b
#if canImport(Darwin)
            case .virtualMemory:
                return { __DataInvokeDeallocatorVirtualMemory($0, $1) }
#endif // canImport(Darwin)
            }
        }
    }

    // MARK: -
    // MARK: Init methods

    /// Initialize a `Data` with copied memory content.
    ///
    /// - parameter bytes: A pointer to the memory. It will be copied.
    /// - parameter count: The number of bytes to copy.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(bytes: UnsafeRawPointer, count: Int) {
        _representation = _Representation(UnsafeRawBufferPointer(start: bytes, count: count))
    }

    /// Initialize a `Data` with copied memory content.
    ///
    /// - parameter buffer: A buffer pointer to copy. The size is calculated from `SourceType` and `buffer.count`.
    @inlinable // This is @inlinable as a trivial, generic initializer.
    public init<SourceType>(buffer: UnsafeBufferPointer<SourceType>) {
        _representation = _Representation(UnsafeRawBufferPointer(buffer))
    }

    /// Initialize a `Data` with copied memory content.
    ///
    /// - parameter buffer: A buffer pointer to copy. The size is calculated from `SourceType` and `buffer.count`.
    @inlinable // This is @inlinable as a trivial, generic initializer.
    public init<SourceType>(buffer: UnsafeMutableBufferPointer<SourceType>) {
        _representation = _Representation(UnsafeRawBufferPointer(buffer))
    }

    /// Initialize a `Data` with a repeating byte pattern
    ///
    /// - parameter repeatedValue: A byte to initialize the pattern
    /// - parameter count: The number of bytes the data initially contains initialized to the repeatedValue
    @inlinable // This is @inlinable as a convenience initializer.
    public init(repeating repeatedValue: UInt8, count: Int) {
        self.init(count: count)
        withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Void in
            _ = memset(buffer.baseAddress!, Int32(repeatedValue), buffer.count)
        }
    }

    /// Initialize a `Data` with the specified size.
    ///
    /// This initializer doesn't necessarily allocate the requested memory right away. `Data` allocates additional memory as needed, so `capacity` simply establishes the initial capacity. When it does allocate the initial memory, though, it allocates the specified amount.
    ///
    /// This method sets the `count` of the data to 0.
    ///
    /// If the capacity specified in `capacity` is greater than four memory pages in size, this may round the amount of requested memory up to the nearest full page.
    ///
    /// - parameter capacity: The size of the data.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(capacity: Int) {
        _representation = _Representation(capacity: capacity)
    }

    /// Initialize a `Data` with the specified count of zeroed bytes.
    ///
    /// - parameter count: The number of bytes the data initially contains.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(count: Int) {
        _representation = _Representation(count: count)
    }

    /// Initialize an empty `Data`.
    @inlinable // This is @inlinable as a trivial initializer.
    public init() {
        _representation = .empty
    }


    /// Initialize a `Data` without copying the bytes.
    ///
    /// If the result is mutated and is not a unique reference, then the `Data` will still follow copy-on-write semantics. In this case, the copy will use its own deallocator. Therefore, it is usually best to only use this initializer when you either enforce immutability with `let` or ensure that no other references to the underlying data are formed.
    /// - parameter bytes: A pointer to the bytes.
    /// - parameter count: The size of the bytes.
    /// - parameter deallocator: Specifies the mechanism to free the indicated buffer, or `.none`.
    @inlinable // This is @inlinable as a trivial initializer.
    public init(bytesNoCopy bytes: UnsafeMutableRawPointer, count: Int, deallocator: Deallocator) {
        let whichDeallocator = deallocator._deallocator
        if count == 0 {
            deallocator._deallocator(bytes, count)
            _representation = .empty
        } else {
            _representation = _Representation(__DataStorage(bytes: bytes, length: count, copy: false, deallocator: whichDeallocator, offset: 0), count: count)
        }
    }

    // slightly faster paths for common sequences
    @inlinable // This is @inlinable as an important generic funnel point, despite being a non-trivial initializer.
    public init<S: Sequence>(_ elements: S) where S.Element == UInt8 {
        // If the sequence is already contiguous, access the underlying raw memory directly.
        if let contiguous = elements as? ContiguousBytes {
            _representation = contiguous.withUnsafeBytes { return _Representation($0) }
            return
        }

        // The sequence might still be able to provide direct access to typed memory.
        // NOTE: It's safe to do this because we're already guarding on S's element as `UInt8`. This would not be safe on arbitrary sequences.
        let representation = elements.withContiguousStorageIfAvailable {
            _Representation(UnsafeRawBufferPointer($0))
        }
        if let representation = representation {
            _representation = representation
            return
        }

        // Copy as much as we can in one shot from the sequence.
        let underestimatedCount = elements.underestimatedCount
        _representation = _Representation(count: underestimatedCount)
        var (iter, endIndex): (S.Iterator, Int) = _representation.withUnsafeMutableBytes { buffer in
            buffer.withMemoryRebound(to: UInt8.self) {
                elements._copyContents(initializing: $0)
            }
        }
        guard endIndex == _representation.count else {
            // We can't trap here. We have to allow an underfilled buffer
            // to emulate the previous implementation.
            _representation.replaceSubrange(endIndex ..< _representation.endIndex, with: nil, count: 0)
            return
        }

        // Append the rest byte-wise, buffering through an InlineData.
        var buffer = InlineData()
        while let element = iter.next() {
            buffer.append(byte: element)
            if buffer.count == buffer.capacity {
                buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
                buffer.count = 0
            }
        }

        // If we've still got bytes left in the buffer (i.e. the loop ended before we filled up the buffer and cleared it out), append them.
        if buffer.count > 0 {
            buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
            buffer.count = 0
        }
    }

    @available(swift, introduced: 4.2)
    @available(swift, deprecated: 5, message: "use `init(_:)` instead")
    public init<S: Sequence>(bytes elements: S) where S.Iterator.Element == UInt8 {
        self.init(elements)
    }

    @available(swift, obsoleted: 4.2)
    public init(bytes: Array<UInt8>) {
       self.init(bytes)
    }

    @available(swift, obsoleted: 4.2)
    public init(bytes: ArraySlice<UInt8>) {
       self.init(bytes)
    }

    @inlinable // This is @inlinable as a trivial initializer.
    internal init(representation: _Representation) {
        _representation = representation
    }

#if FOUNDATION_FRAMEWORK
    public typealias ReadingOptions = NSData.ReadingOptions
    public typealias WritingOptions = NSData.WritingOptions
#else
    public struct ReadingOptions : OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        public static let mappedIfSafe = ReadingOptions(rawValue: 1 << 0)
        public static let uncached = ReadingOptions(rawValue: 1 << 1)
        public static let alwaysMapped = ReadingOptions(rawValue: 1 << 3)
    }
    
    // This is imported from the ObjC 'option set', which is actually a combination of an option and an enumeration (file protection).
    public struct WritingOptions : OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        /// An option to write data to an auxiliary file first and then replace the original file with the auxiliary file when the write completes.
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

    /// Initialize a `Data` with the contents of a `URL`.
    ///
    /// - parameter url: The `URL` to read.
    /// - parameter options: Options for the read operation. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if `url` cannot be read.
    public init(contentsOf url: __shared URL, options: ReadingOptions = []) throws {
#if NO_FILESYSTEM
        let d = try NSData(contentsOf: url, options: NSData.ReadingOptions(rawValue: options.rawValue))
        self.init(referencing: d)
#else
        if url.isFileURL {
            self = try readDataFromFile(path: .url(url), reportProgress: true, options: options)
        } else {
            #if FOUNDATION_FRAMEWORK
            // Fallback to NSData, to read via NSURLSession
            let d = try NSData(contentsOf: url, options: NSData.ReadingOptions(rawValue: options.rawValue))
            self.init(referencing: d)
            #else
            throw CocoaError(.fileReadUnsupportedScheme)
            #endif
        }
#endif
    }
    
    internal init(contentsOfFile path: String, options: ReadingOptions = []) throws {
#if NO_FILESYSTEM
        let d = try NSData(contentsOfFile: path, options: NSData.ReadingOptions(rawValue: options.rawValue))
        self.init(referencing: d)
#else
        self = try readDataFromFile(path: .path(path), reportProgress: true, options: options)
#endif
    }
    
    // -----------------------------------
    // MARK: - Properties and Functions

    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        _representation.reserveCapacity(minimumCapacity)
    }

    mutating func stabilizeAddresses() {
        reserveCapacity(InlineData.maximumCapacity + 1)
    }

    /// The number of bytes in the data.
    @inlinable // This is @inlinable as trivially forwarding.
    public var count: Int {
        get {
            return _representation.count
        }
        set(newValue) {
            precondition(newValue >= 0, "count must not be negative")
            _representation.count = newValue
        }
    }

    @inlinable // This is @inlinable as trivially computable.
    public var regions: CollectionOfOne<Data> {
        return CollectionOfOne(self)
    }

    /// Access the bytes in the data.
    ///
    /// - warning: The byte pointer argument should not be stored and used outside of the lifetime of the call to the closure.
    @available(swift, deprecated: 5, message: "use `withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) rethrows -> R` instead")
    public func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeBytes {
            return try body($0.baseAddress?.assumingMemoryBound(to: ContentType.self) ?? UnsafePointer<ContentType>(bitPattern: 0xBAD0)!)
        }
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeBytes(body)
    }
    
    @_alwaysEmitIntoClient
    public func withContiguousStorageIfAvailable<ResultType>(_ body: (_ buffer: UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType? {
        return try _representation.withUnsafeBytes {
            return try $0.withMemoryRebound(to: UInt8.self, body)
        }
    }

    /// Mutate the bytes in the data.
    ///
    /// This function assumes that you are mutating the contents.
    /// - warning: The byte pointer argument should not be stored and used outside of the lifetime of the call to the closure.
    @available(swift, deprecated: 5, message: "use `withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R` instead")
    public mutating func withUnsafeMutableBytes<ResultType, ContentType>(_ body: (UnsafeMutablePointer<ContentType>) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeMutableBytes {
            return try body($0.baseAddress?.assumingMemoryBound(to: ContentType.self) ?? UnsafeMutablePointer<ContentType>(bitPattern: 0xBAD0)!)
        }
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func withUnsafeMutableBytes<ResultType>(_ body: (UnsafeMutableRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try _representation.withUnsafeMutableBytes(body)
    }

    // MARK: -
    // MARK: Copy Bytes

    /// Copy the contents of the data to a pointer.
    ///
    /// - parameter pointer: A pointer to the buffer you wish to copy the bytes into.
    /// - parameter count: The number of bytes to copy.
    /// - warning: This method does not verify that the contents at pointer have enough space to hold `count` bytes.
    @inlinable // This is @inlinable as trivially forwarding.
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        precondition(count >= 0, "count of bytes to copy must not be negative")
        if count == 0 { return }
        _copyBytesHelper(to: UnsafeMutableRawPointer(pointer), from: startIndex..<(startIndex + count))
    }

    @inlinable // This is @inlinable as trivially forwarding.
    internal func _copyBytesHelper(to pointer: UnsafeMutableRawPointer, from range: Range<Int>) {
        if range.isEmpty { return }
        _representation.copyBytes(to: pointer, from: range)
    }

    /// Copy a subset of the contents of the data to a pointer.
    ///
    /// - parameter pointer: A pointer to the buffer you wish to copy the bytes into.
    /// - parameter range: The range in the `Data` to copy.
    /// - warning: This method does not verify that the contents at pointer have enough space to hold the required number of bytes.
    @inlinable // This is @inlinable as trivially forwarding.
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, from range: Range<Index>) {
        _copyBytesHelper(to: pointer, from: range)
    }

    // Copy the contents of the data into a buffer.
    ///
    /// This function copies the bytes in `range` from the data into the buffer. If the count of the `range` is greater than `MemoryLayout<DestinationType>.stride * buffer.count` then the first N bytes will be copied into the buffer.
    /// - precondition: The range must be within the bounds of the data. Otherwise `fatalError` is called.
    /// - parameter buffer: A buffer to copy the data into.
    /// - parameter range: A range in the data to copy into the buffer. If the range is empty, this function will return 0 without copying anything. If the range is nil, as much data as will fit into `buffer` is copied.
    /// - returns: Number of bytes copied into the destination buffer.
    @inlinable // This is @inlinable as generic and reasonably small.
    public func copyBytes<DestinationType>(to buffer: UnsafeMutableBufferPointer<DestinationType>, from range: Range<Index>? = nil) -> Int {
        let cnt = count
        guard cnt > 0 else { return 0 }

        let copyRange : Range<Index>
        if let r = range {
            guard !r.isEmpty else { return 0 }
            copyRange = r.lowerBound..<(r.lowerBound + Swift.min(buffer.count * MemoryLayout<DestinationType>.stride, r.upperBound - r.lowerBound))
        } else {
            copyRange = startIndex..<(startIndex + Swift.min(buffer.count * MemoryLayout<DestinationType>.stride, cnt))
        }

        guard !copyRange.isEmpty else { return 0 }

        _copyBytesHelper(to: buffer.baseAddress!, from: copyRange)
        return copyRange.upperBound - copyRange.lowerBound
    }

    // MARK: -

    /// Enumerate the contents of the data.
    ///
    /// In some cases, (for example, a `Data` backed by a `dispatch_data_t`, the bytes may be stored discontinuously. In those cases, this function invokes the closure for each contiguous region of bytes.
    /// - parameter block: The closure to invoke for each region of data. You may stop the enumeration by setting the `stop` parameter to `true`.
    @available(swift, deprecated: 5, message: "use `regions` or `for-in` instead")
    public func enumerateBytes(_ block: (_ buffer: UnsafeBufferPointer<UInt8>, _ byteIndex: Index, _ stop: inout Bool) -> Void) {
        _representation.enumerateBytes(block)
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    internal mutating func _append<SourceType>(_ buffer : UnsafeBufferPointer<SourceType>) {
        if buffer.isEmpty { return }
        _representation.append(contentsOf: UnsafeRawBufferPointer(buffer))
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func append(_ bytes: UnsafePointer<UInt8>, count: Int) {
        if count == 0 { return }
        _append(UnsafeBufferPointer(start: bytes, count: count))
    }

    public mutating func append(_ other: Data) {
        guard !other.isEmpty else { return }
        other.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            _representation.append(contentsOf: buffer)
        }
    }

    /// Append a buffer of bytes to the data.
    ///
    /// - parameter buffer: The buffer of bytes to append. The size is calculated from `SourceType` and `buffer.count`.
    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func append<SourceType>(_ buffer : UnsafeBufferPointer<SourceType>) {
        _append(buffer)
    }

    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func append(contentsOf bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<UInt8>) -> Void in
            _append(buffer)
        }
    }

    @inlinable // This is @inlinable as an important generic funnel point, despite being non-trivial.
    public mutating func append<S: Sequence>(contentsOf elements: S) where S.Element == Element {
        // If the sequence is already contiguous, access the underlying raw memory directly.
        if let contiguous = elements as? ContiguousBytes {
            contiguous.withUnsafeBytes {
                _representation.append(contentsOf: $0)
            }

            return
        }

        // The sequence might still be able to provide direct access to typed memory.
        // NOTE: It's safe to do this because we're already guarding on S's element as `UInt8`. This would not be safe on arbitrary sequences.
        let appended: Void? = elements.withContiguousStorageIfAvailable {
            _representation.append(contentsOf: UnsafeRawBufferPointer($0))
        }
        guard appended == nil else { return }

        // The sequence is really not contiguous.
        // Copy as much as we can in one shot.
        let underestimatedCount = elements.underestimatedCount
        let originalCount = _representation.count
        resetBytes(in: self.endIndex ..< self.endIndex + underestimatedCount)
        var (iter, copiedCount): (S.Iterator, Int) = _representation.withUnsafeMutableBytes { buffer in
            assert(buffer.count == originalCount + underestimatedCount)
            let start = buffer.baseAddress?.advanced(by: originalCount)
            let b = UnsafeMutableRawBufferPointer(start: start, count: buffer.count - originalCount)
            return b.withMemoryRebound(to: UInt8.self, elements._copyContents(initializing:))
        }
        guard copiedCount == underestimatedCount else {
            // We can't trap here. We have to allow an underfilled buffer
            // to emulate the previous implementation.
            _representation.replaceSubrange(startIndex + originalCount + copiedCount ..< endIndex, with: nil, count: 0)
            return
        }

        // Append the rest byte-wise, buffering through an InlineData.
        var buffer = InlineData()
        while let element = iter.next() {
            buffer.append(byte: element)
            if buffer.count == buffer.capacity {
                buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
                buffer.count = 0
            }
        }

        // If we've still got bytes left in the buffer (i.e. the loop ended before we filled up the buffer and cleared it out), append them.
        if buffer.count > 0 {
            buffer.withUnsafeBytes { _representation.append(contentsOf: $0) }
            buffer.count = 0
        }
    }

    // MARK: -

    /// Set a region of the data to `0`.
    ///
    /// If `range` exceeds the bounds of the data, then the data is resized to fit.
    /// - parameter range: The range in the data to set to `0`.
    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func resetBytes(in range: Range<Index>) {
        // it is worth noting that the range here may be out of bounds of the Data itself (which triggers a growth)
        precondition(range.lowerBound >= 0, "Ranges must not be negative bounds")
        precondition(range.upperBound >= 0, "Ranges must not be negative bounds")
        _representation.resetBytes(in: range)
    }

    /// Replace a region of bytes in the data with new data.
    ///
    /// This will resize the data if required, to fit the entire contents of `data`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace. If `subrange.lowerBound == data.count && subrange.count == 0` then this operation is an append.
    /// - parameter data: The replacement data.
    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func replaceSubrange(_ subrange: Range<Index>, with data: Data) {
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: buffer.count)
        }
    }

    /// Replace a region of bytes in the data with new bytes from a buffer.
    ///
    /// This will resize the data if required, to fit the entire contents of `buffer`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace.
    /// - parameter buffer: The replacement bytes.
    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public mutating func replaceSubrange<SourceType>(_ subrange: Range<Index>, with buffer: UnsafeBufferPointer<SourceType>) {
        guard !buffer.isEmpty  else { return }
        replaceSubrange(subrange, with: buffer.baseAddress!, count: buffer.count * MemoryLayout<SourceType>.stride)
    }

    /// Replace a region of bytes in the data with new bytes from a collection.
    ///
    /// This will resize the data if required, to fit the entire contents of `newElements`.
    ///
    /// - precondition: The bounds of `subrange` must be valid indices of the collection.
    /// - parameter subrange: The range in the data to replace.
    /// - parameter newElements: The replacement bytes.
    @inlinable // This is @inlinable as generic and reasonably small.
    public mutating func replaceSubrange<ByteCollection : Collection>(_ subrange: Range<Index>, with newElements: ByteCollection) where ByteCollection.Iterator.Element == Data.Iterator.Element {
        // If the collection is already contiguous, access the underlying raw memory directly.
        if let contiguous = newElements as? ContiguousBytes {
            contiguous.withUnsafeBytes { buffer in
                _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: buffer.count)
            }
            return
        }
        // The collection might still be able to provide direct access to typed memory.
        // NOTE: It's safe to do this because we're already guarding on ByteCollection's element as `UInt8`. This would not be safe on arbitrary collections.
        let replaced: Void? = newElements.withContiguousStorageIfAvailable { buffer in
            _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: buffer.count)
        }
        guard replaced == nil else { return }

        let totalCount = Int(newElements.count)
        _withStackOrHeapBuffer(capacity: totalCount) { buffer in
            var (iterator, index) = newElements._copyContents(initializing: buffer)
            precondition(index == buffer.endIndex, "Collection has less elements than its count")
            precondition(iterator.next() == nil, "Collection has more elements than its count")
            _representation.replaceSubrange(subrange, with: buffer.baseAddress, count: totalCount)
        }
    }

    @inlinable // This is @inlinable as trivially forwarding.
    public mutating func replaceSubrange(_ subrange: Range<Index>, with bytes: UnsafeRawPointer, count cnt: Int) {
        _representation.replaceSubrange(subrange, with: bytes, count: cnt)
    }

    /// Return a new copy of the data in a specified range.
    ///
    /// - parameter range: The range to copy.
    public func subdata(in range: Range<Index>) -> Data {
        if isEmpty || range.upperBound - range.lowerBound == 0 {
            return Data()
        }
        let slice = self[range]

        return slice.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Data in
            return Data(bytes: buffer.baseAddress!, count: buffer.count)
        }
    }

    // MARK: -
    
    /// Write the contents of the `Data` to a location.
    ///
    /// - parameter url: The location to write the data into.
    /// - parameter options: Options for writing the data. Default value is `[]`.
    /// - throws: An error in the Cocoa domain, if there is an error writing to the `URL`.
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
        if options.contains(.withoutOverwriting) && options.contains(.atomic) {
            fatalError("withoutOverwriting is not supported with atomic")
        }
        
        guard url.isFileURL else {
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
        
#if !NO_FILESYSTEM
        try writeToFile(path: .url(url), data: self, options: options, reportProgress: true)
#else
        throw CocoaError(.featureUnsupported)
#endif
    }

    // MARK: -
    //

    /// The hash value for the data.
    @inline(never) // This is not inlinable as emission into clients could cause cross-module inconsistencies if they are not all recompiled together.
    public func hash(into hasher: inout Hasher) {
        _representation.hash(into: &hasher)
    }

    public func advanced(by amount: Int) -> Data {
        precondition(amount >= 0)
        let start = self.index(self.startIndex, offsetBy: amount)
        precondition(start <= self.endIndex)
        return Data(self[start...])
    }

    // MARK: -

    // MARK: -
    // MARK: Index and Subscript

    /// Sets or returns the byte at the specified index.
    @inlinable // This is @inlinable as trivially forwarding.
    public subscript(index: Index) -> UInt8 {
        get {
            return _representation[index]
        }
        set(newValue) {
            _representation[index] = newValue
        }
    }

    @inlinable // This is @inlinable as trivially forwarding.
    public subscript(bounds: Range<Index>) -> Data {
        get {
            return _representation[bounds]
        }
        set {
            replaceSubrange(bounds, with: newValue)
        }
    }

    @inlinable // This is @inlinable as a generic, trivially forwarding function.
    public subscript<R: RangeExpression>(_ rangeExpression: R) -> Data
        where R.Bound: FixedWidthInteger {
        get {
            let lower = R.Bound(startIndex)
            let upper = R.Bound(endIndex)
            let range = rangeExpression.relative(to: lower..<upper)
            let start = Int(range.lowerBound)
            let end = Int(range.upperBound)
            let r: Range<Int> = start..<end
            return _representation[r]
        }
        set {
            let lower = R.Bound(startIndex)
            let upper = R.Bound(endIndex)
            let range = rangeExpression.relative(to: lower..<upper)
            let start = Int(range.lowerBound)
            let end = Int(range.upperBound)
            let r: Range<Int> = start..<end
            replaceSubrange(r, with: newValue)
        }

    }

    /// The start `Index` in the data.
    @inlinable // This is @inlinable as trivially forwarding.
    public var startIndex: Index {
        get {
            return _representation.startIndex
        }
    }

    /// The end `Index` into the data.
    ///
    /// This is the "one-past-the-end" position, and will always be equal to the `count`.
    @inlinable // This is @inlinable as trivially forwarding.
    public var endIndex: Index {
        get {
            return _representation.endIndex
        }
    }

    @inlinable // This is @inlinable as trivially computable.
    public func index(before i: Index) -> Index {
        return i - 1
    }

    @inlinable // This is @inlinable as trivially computable.
    public func index(after i: Index) -> Index {
        return i + 1
    }

    @inlinable // This is @inlinable as trivially computable.
    public var indices: Range<Int> {
        get {
            return startIndex..<endIndex
        }
    }

    @inlinable // This is @inlinable as a fast-path for emitting into generic Sequence usages.
    public func _copyContents(initializing buffer: UnsafeMutableBufferPointer<UInt8>) -> (Iterator, UnsafeMutableBufferPointer<UInt8>.Index) {
        guard !isEmpty else { return (makeIterator(), buffer.startIndex) }
        let cnt = Swift.min(count, buffer.count)

        withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            _ = memcpy(UnsafeMutableRawPointer(buffer.baseAddress!), bytes.baseAddress!, cnt)
        }

        return (Iterator(self, at: startIndex + cnt), buffer.index(buffer.startIndex, offsetBy: cnt))
    }

    /// An iterator over the contents of the data.
    ///
    /// The iterator will increment byte-by-byte.
    @inlinable // This is @inlinable as trivially computable.
    public func makeIterator() -> Data.Iterator {
        return Iterator(self, at: startIndex)
    }

    public struct Iterator : IteratorProtocol, Sendable {
        @usableFromInline
        internal typealias Buffer = (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

        @usableFromInline internal let _data: Data
        @usableFromInline internal var _buffer: Buffer
        @usableFromInline internal var _idx: Data.Index
        @usableFromInline internal let _endIdx: Data.Index

        @usableFromInline // This is @usableFromInline as a non-trivial initializer.
        internal init(_ data: Data, at loc: Data.Index) {
            // The let vars prevent this from being marked as @inlinable
            _data = data
            _buffer = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            _idx = loc
            _endIdx = data.endIndex

            let bufferSize = MemoryLayout<Buffer>.size
            Swift.withUnsafeMutableBytes(of: &_buffer) {
                $0.withMemoryRebound(to: UInt8.self) { [endIndex = data.endIndex] buf in
                    let bufferIdx = (loc - data.startIndex) % bufferSize
                    let end = (endIndex - (loc - bufferIdx) > bufferSize) ? (loc - bufferIdx + bufferSize) : endIndex
                    data.copyBytes(to: buf, from: (loc - bufferIdx)..<end)
                }
            }
        }

        public mutating func next() -> UInt8? {
            let idx = _idx
            let bufferSize = MemoryLayout<Buffer>.size

            guard idx < _endIdx else { return nil }
            _idx += 1

            let bufferIdx = (idx - _data.startIndex) % bufferSize


            if bufferIdx == 0 {
                var buffer = _buffer
                Swift.withUnsafeMutableBytes(of: &buffer) {
                    $0.withMemoryRebound(to: UInt8.self) {
                        // populate the buffer
                        _data.copyBytes(to: $0, from: idx..<(_endIdx - idx > bufferSize ? idx + bufferSize : _endIdx))
                    }
                }
                _buffer = buffer
            }

            return Swift.withUnsafeMutableBytes(of: &_buffer) {
                $0.load(fromByteOffset: bufferIdx, as: UInt8.self)
            }
        }
    }

    // MARK: - Range
    
#if FOUNDATION_FRAMEWORK
    /// Find the given `Data` in the content of this `Data`.
    ///
    /// - parameter dataToFind: The data to be searched for.
    /// - parameter options: Options for the search. Default value is `[]`.
    /// - parameter range: The range of this data in which to perform the search. Default value is `nil`, which means the entire content of this data.
    /// - returns: A `Range` specifying the location of the found data, or nil if a match could not be found.
    /// - precondition: `range` must be in the bounds of the Data.
    public func range(of dataToFind: Data, options: Data.SearchOptions = [], in range: Range<Index>? = nil) -> Range<Index>? {
        let nsRange : NSRange
        if let r = range {
            nsRange = NSRange(location: r.lowerBound - startIndex, length: r.upperBound - r.lowerBound)
        } else {
            nsRange = NSRange(location: 0, length: count)
        }
        let result = _representation.withInteriorPointerReference {
            let opts = NSData.SearchOptions(rawValue: options.rawValue)
            return $0.range(of: dataToFind, options: opts, in: nsRange)
        }
        if result.location == NSNotFound {
            return nil
        }
        return (result.location + startIndex)..<((result.location + startIndex) + result.length)
    }
#else
    // TODO: Implement range(of:options:in:) for Foundation package.
#endif

    // MARK: -
    //

    /// Returns `true` if the two `Data` arguments are equal.
    @inlinable // This is @inlinable as emission into clients is safe -- the concept of equality on Data will not change.
    public static func ==(d1 : Data, d2 : Data) -> Bool {
        let length1 = d1.count
        if length1 != d2.count {
            return false
        }
        if length1 > 0 {
            return d1.withUnsafeBytes { (b1: UnsafeRawBufferPointer) in
                return d2.withUnsafeBytes { (b2: UnsafeRawBufferPointer) in
                    return memcmp(b1.baseAddress!, b2.baseAddress!, b2.count) == 0
                }
            }
        }
        return true
    }
}

#if !FOUNDATION_FRAMEWORK
// MARK: Exported Types
extension Data {
    public struct SearchOptions : OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        /// Search from the end of the data object.
        public static let backwards = SearchOptions(rawValue: 1 << 0)
        /// Search is limited to start (or end, if searching backwards) of the data object.
        public static let anchored  = SearchOptions(rawValue: 1 << 1)
    }

    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public struct Base64EncodingOptions : OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        /// Set the maximum line length to 64 characters, after which a line ending is inserted.
        public static let lineLength64Characters = Base64EncodingOptions(rawValue: 1 << 0)
        /// Set the maximum line length to 76 characters, after which a line ending is inserted.
        public static let lineLength76Characters = Base64EncodingOptions(rawValue: 1 << 1)
        /// When a maximum line length is set, specify that the line ending to insert should include a carriage return.
        public static let endLineWithCarriageReturn = Base64EncodingOptions(rawValue: 1 << 4)
        /// When a maximum line length is set, specify that the line ending to insert should include a line feed.
        public static let endLineWithLineFeed       = Base64EncodingOptions(rawValue: 1 << 5)
    }

    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public struct Base64DecodingOptions : OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        /// Modify the decoding algorithm so that it ignores unknown non-Base-64 bytes, including line ending characters.
        public static let ignoreUnknownCharacters = Base64DecodingOptions(rawValue: 1 << 0)
    }
}
#else
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {
    // These types are typealiased to the `NSData` options for framework builds only.
    public typealias SearchOptions = NSData.SearchOptions
    public typealias Base64EncodingOptions = NSData.Base64EncodingOptions
    public typealias Base64DecodingOptions = NSData.Base64DecodingOptions
}
#endif //!FOUNDATION_FRAMEWORK


@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data : CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// A human-readable description for the data.
    public var description: String {
        return "\(self.count) bytes"
    }

    /// A human-readable debug description for the data.
    public var debugDescription: String {
        return self.description
    }

    public var customMirror: Mirror {
        let nBytes = self.count
        var children: [(label: String?, value: Any)] = []
        children.append((label: "count", value: nBytes))

        self.withUnsafeBytes { (bytes : UnsafeRawBufferPointer) in
            children.append((label: "pointer", value: bytes.baseAddress!))
        }

        // Minimal size data is output as an array
        if nBytes < 64 {
            children.append((label: "bytes", value: Array(self[startIndex..<Swift.min(nBytes + startIndex, endIndex)])))
        }

        let m = Mirror(self, children:children, displayStyle: Mirror.DisplayStyle.struct)
        return m
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data : Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        // It's more efficient to pre-allocate the buffer if we can.
        if let count = container.count {
            self.init(count: count)

            // Loop only until count, not while !container.isAtEnd, in case count is underestimated (this is misbehavior) and we haven't allocated enough space.
            // We don't want to write past the end of what we allocated.
            for i in 0 ..< count {
                let byte = try container.decode(UInt8.self)
                self[i] = byte
            }
        } else {
            self.init()
        }

        while !container.isAtEnd {
            var byte = try container.decode(UInt8.self)
            self.append(&byte, count: 1)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            try container.encode(contentsOf: buffer)
        }
    }
}
