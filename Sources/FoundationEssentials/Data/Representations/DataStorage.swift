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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#elseif canImport(Bionic)
@preconcurrency import Bionic
#endif

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
    
    static func allocate(_ size: Int, _ clear: Bool) -> UnsafeMutableRawPointer? {
#if canImport(Darwin) && _pointerBitWidth(_64) && !NO_TYPED_MALLOC
        var typeDesc = malloc_type_descriptor_v0_t()
        typeDesc.summary.layout_semantics.contains_generic_data = true
        if clear {
            return malloc_type_calloc(1, size, typeDesc.type_id);
        } else {
            return malloc_type_malloc(size, typeDesc.type_id);
        }
#else
        if clear {
            return calloc(1, size)
        } else {
            return malloc(size)
        }
#endif
    }
    
    static func reallocate(_ ptr: UnsafeMutableRawPointer, _ newSize: Int) -> UnsafeMutableRawPointer? {
#if canImport(Darwin) && _pointerBitWidth(_64) && !NO_TYPED_MALLOC
        var typeDesc = malloc_type_descriptor_v0_t()
        typeDesc.summary.layout_semantics.contains_generic_data = true
        return malloc_type_realloc(ptr, newSize, typeDesc.type_id);
#else
        return realloc(ptr, newSize)
#endif
    }
    
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
        return _bytes?.advanced(by: _offset &* -1) // _offset is guaranteed to be non-negative, so it can never overflow when negating
    }
    
    @inlinable
    static var copyWillRetainMask: Int {
#if _pointerBitWidth(_64)
        return Int(bitPattern: 0x8000000000000000)
#elseif _pointerBitWidth(_32)
        return Int(bitPattern: 0x80000000)
#endif
    }
    
    @inlinable
    static var capacityMask: Int {
#if _pointerBitWidth(_64)
        return Int(bitPattern: 0x7FFFFFFFFFFFFFFF)
#elseif _pointerBitWidth(_32)
        return Int(bitPattern: 0x7FFFFFFF)
#endif
    }
    
    @inlinable // This is @inlinable as trivially computable.
    var capacity: Int {
        return _capacity & __DataStorage.capacityMask
    }
    
    @inlinable
    var _copyWillRetain: Bool {
        get {
            return _capacity & __DataStorage.copyWillRetainMask == 0
        }
        set {
            if !newValue {
                _capacity |= __DataStorage.copyWillRetainMask
            } else {
                _capacity &= __DataStorage.capacityMask
            }
        }
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
        if capacity < newLength || _bytes == nil {
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
        if capacity < newLength || _bytes == nil {
            ensureUniqueBufferReference(growingTo: newLength, clear: false)
        }
        _length = newLength
        __DataStorage.move(_bytes!.advanced(by: origLength), bytes, length)
    }
    
    @_alwaysEmitIntoClient
    func withUninitializedBytes<Result: ~Copyable, E: Error>(
        _ newCapacity: Int, _ newCount: inout Int, _ initializer: (inout OutputRawSpan) throws(E) -> Result
    ) throws(E) -> Result {
        let buffer = UnsafeMutableRawBufferPointer(start: mutableBytes!.advanced(by: _length), count: newCapacity &- _length)
        var outputSpan = OutputRawSpan(buffer: buffer, initializedCount: 0)
        defer {
            newCount = outputSpan.finalize(for: buffer)
            _length &+= newCount
            outputSpan = OutputRawSpan()
        }
        return try initializer(&outputSpan)
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
    
    // This was an ABI entrypoint added in macOS 14-aligned releases in an attempt to work around the original declaration using NSRange instead of Range<Int>
    // Using this entrypoint from existing inlinable code required an availability check, and that check has proved to be extremely expensive
    // This entrypoint is left to preserve ABI compatibility, but inlinable code has since switched back to calling the original entrypoint using a tuple that is layout-compatible with NSRange
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @usableFromInline
    func replaceBytes(in range_: Range<Int>, with replacementBytes: UnsafeRawPointer?, length replacementLength: Int) {
        // Call through to the main implementation
        self.replaceBytes(in: (range_.lowerBound, range_.upperBound &- range_.lowerBound), with: replacementBytes, length: replacementLength)
    }
    
    // This utility function was originally written in terms of NSRange instead of Range<Int>. On Darwin platforms, it is also an ABI entry point so we need to continue accepting NSRange values from code that has been inlined into callers.
    // To avoid requiring the use of NSRange in source, we instead use a tuple that is layout-compatible with NSRange. On Darwin platforms, we can use `@_silgen_name to preserve the original symbol name that refers to NSRange.
    @usableFromInline
    #if FOUNDATION_FRAMEWORK
    @_silgen_name("$s10Foundation13__DataStorageC12replaceBytes2in4with6lengthySo8_NSRangeV_SVSgSitF")
    #endif
    internal func replaceBytes(in range_: (location: Int, length: Int), with replacementBytes: UnsafeRawPointer?, length replacementLength: Int) {
        let range = (location: range_.location - _offset, length: range_.length)
        let currentLength = _length
        let resultingLength = currentLength - range.length + replacementLength
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
        let start = range.location
        let length = range.length
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
            if capacity <= range.upperBound {
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
