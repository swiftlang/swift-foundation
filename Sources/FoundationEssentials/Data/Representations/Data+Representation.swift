//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension Data {
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
}
