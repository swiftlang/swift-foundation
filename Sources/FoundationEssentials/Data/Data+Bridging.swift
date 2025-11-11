//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

internal import _ForSwiftFoundation

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension __DataStorage {
    @inline(never) // This is not @inlinable to avoid emission of the private `__NSSwiftData` class name into clients.
    @usableFromInline
    func bridgedReference(_ range: Range<Int>) -> AnyObject {
        if range.isEmpty {
            return NSData() // zero length data can be optimized as a singleton
        }
        
        return __NSSwiftData(backing: self, range: range)
    }
}

// NOTE: older overlays called this _NSSwiftData. The two must
// coexist, so it was renamed. The old name must not be used in the new
// runtime.
internal final class __NSSwiftData : NSData {
    var _backing: __DataStorage!
    var _range: Range<Data.Index>!
    
    convenience init(backing: __DataStorage, range: Range<Data.Index>) {
        self.init()
        _backing = backing
        _range = range
    }
    @objc override var length: Int {
        return _range.upperBound - _range.lowerBound
    }
    
    @objc override var bytes: UnsafeRawPointer {
        // NSData's byte pointer methods are not annotated for nullability correctly
        // (but assume non-null by the wrapping macro guards). This placeholder value
        // is to work-around this bug. Any indirection to the underlying bytes of an NSData
        // with a length of zero would have been a programmer error anyhow so the actual
        // return value here is not needed to be an allocated value. This is specifically
        // needed to live like this to be source compatible with Swift3. Beyond that point
        // this API may be subject to correction.
        guard let bytes = _backing.bytes else {
            return UnsafeRawPointer(bitPattern: 0xBAD0)!
        }
        
        return bytes.advanced(by: _range.lowerBound)
    }
    
    @objc override func copy(with zone: NSZone? = nil) -> Any {
        if _backing._copyWillRetain {
            return self
        } else {
            return NSData(bytes: bytes, length: length)
        }
        
    }
    
    @objc override func mutableCopy(with zone: NSZone? = nil) -> Any {
        return NSMutableData(bytes: bytes, length: length)
    }
    
    @objc override
    func _isCompact() -> Bool {
        return true
    }
    
    @objc override
    func _bridgingCopy(_ bytes: UnsafeMutablePointer<UnsafeRawPointer?>, length: UnsafeMutablePointer<Int>) -> Data? {
        fatalError("Unexpected call to __NSSwiftData._bridgingCopy(_:length:)")
    }
}

extension Data {
    internal func _bridgeToObjectiveCImpl() -> AnyObject {
        switch _representation {
        case .empty: return NSData()
        case .inline(let inline):
            return inline.withUnsafeBytes {
                return NSData(bytes: $0.baseAddress, length: $0.count)
            }
        case .slice(let slice):
            return slice.storage.bridgedReference(slice.range)
        case .large(let slice):
            return slice.storage.bridgedReference(slice.range)
        }
    }
    
    internal static func _bridgeFromObjectiveCAdoptingNativeStorageOf(_ source: AnyObject) -> Data? {
        guard object_getClass(source) == __NSSwiftData.self else { return nil }
        
        let swiftData = unsafeDowncast(source, to: __NSSwiftData.self)
        let range = swiftData._range!
        let originalBacking = swiftData._backing!
        
        // (rdar://162776451) Some clients assume that the double-bridged Data's start index is 0 due to historical behavior. We need to make sure the created Data's indices begin at 0 rather than preserving the original offset/slice range here. This requires creating a new __DataStorage instead of using the existing one.
        // (rdar://121865256) We also need to make sure that we don't create a new __DataStorage that holds on to the original via the deallocator. If a value is double bridged repeatedly (as is the case in some clients), unwinding in the dealloc can cause a stack overflow. This requires either using the existing __DataStorage, or creating a new one with a copy of the bytes to avoid a deallocator chain.
        // Based on the two constraints above, we perform a copy here. Ideally in the future if we remove the first constraint we could re-use the existing originalBacking to avoid the copy.
        let newBacking = __DataStorage(bytes: originalBacking.mutableBytes?.advanced(by: range.lowerBound), length: range.count)
        
        if InlineSlice.canStore(count: newBacking.length) {
            return Data(representation: .slice(InlineSlice(newBacking, count: newBacking.length)))
        } else {
            return Data(representation: .large(LargeSlice(newBacking, count: newBacking.length)))
        }
    }
}

#endif
