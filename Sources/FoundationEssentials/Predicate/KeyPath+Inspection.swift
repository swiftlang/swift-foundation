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

extension UInt32 {
    private static var KEYPATH_HEADER_BUFFER_SIZE_MASK: UInt32 { 0x00FF_FFFF }
    
    private static var COMPONENT_HEADER_KIND_MASK: UInt32 { 0x7F00_0000 }
    private static var COMPONENT_HEADER_PAYLOAD_MASK: UInt32 { 0x00FF_FFFF }
    
    private static var COMPUTED_COMPONENT_PAYLOAD_ARGUMENTS_MASK: UInt32 { 0x0008_0000 }
    private static var COMPUTED_COMPONENT_PAYLOAD_SETTABLE_MASK: UInt32 { 0x0040_0000 }
    
    private static var STORED_COMPONENT_PAYLOAD_MAXIMUM_INLINE_OFFSET: UInt32 { 0x007F_FFFC }
    
    fileprivate var _keyPathHeader_bufferSize: Int {
        Int(self & Self.KEYPATH_HEADER_BUFFER_SIZE_MASK)
    }
    
    fileprivate var _keyPathComponentHeader_kind: Int {
        Int((self & Self.COMPONENT_HEADER_KIND_MASK) >> 24)
    }
    
    fileprivate var _keyPathComponentHeader_payload: UInt32 {
        self & Self.COMPONENT_HEADER_PAYLOAD_MASK
    }
    
    fileprivate var _keyPathComponentHeader_storedIsInline: Bool {
        // If the payload value is greater than the maximum inline offset then it is one of the out-of-line sentinel values
        _keyPathComponentHeader_payload <= Self.STORED_COMPONENT_PAYLOAD_MAXIMUM_INLINE_OFFSET
    }
    
    fileprivate var _keyPathComponentHeader_computedHasArguments: Bool {
        (_keyPathComponentHeader_payload & Self.COMPUTED_COMPONENT_PAYLOAD_ARGUMENTS_MASK) != 0
    }
    
    fileprivate var _keyPathComponentHeader_computedIsSettable: Bool {
        (_keyPathComponentHeader_payload & Self.COMPUTED_COMPONENT_PAYLOAD_SETTABLE_MASK) != 0
    }
}

extension AnyKeyPath {
    private static var WORD_SIZE: Int { MemoryLayout<Int>.size }
    
    func _validateForPredicateUsage(restrictArguments: Bool = false) {
        var ptr = unsafeBitCast(self, to: UnsafeRawPointer.self)
        ptr = ptr.advanced(by: Self.WORD_SIZE * 3) // skip isa, type metadata, and KVC string pointers
        let header = ptr.load(as: UInt32.self)
        ptr = ptr.advanced(by: Self.WORD_SIZE)
        let firstComponentHeader = ptr.load(as: UInt32.self)
        switch firstComponentHeader._keyPathComponentHeader_kind {
        case 1: // struct/tuple/self stored property
            fallthrough
        case 3: // class stored property
            // Stored property components are either just the payload, or the payload plus 32 bits if the offset is not stored in-line
            // Note: we cannot use MemoryLayout.offset(of:) here because not all single-component keypaths have direct offsets (for example, stored properties in final classes)
            let size = (firstComponentHeader._keyPathComponentHeader_storedIsInline) ? MemoryLayout<UInt32>.size : MemoryLayout<UInt64>.size
            if header._keyPathHeader_bufferSize > size {
                fatalError("Predicate does not support keypaths with multiple components")
            }
        case 2: // computed
            var componentWords = 3
            if firstComponentHeader._keyPathComponentHeader_computedIsSettable {
                componentWords += 1
            }
            if firstComponentHeader._keyPathComponentHeader_computedHasArguments {
                if restrictArguments {
                    fatalError("Predicate does not support keypaths with arguments")
                }
                let capturesSize = ptr.advanced(by: Self.WORD_SIZE * componentWords).load(as: UInt.self)
                componentWords += 2 + (Int(capturesSize) / Self.WORD_SIZE)
            }
            if header._keyPathHeader_bufferSize > (Self.WORD_SIZE * componentWords) {
                fatalError("Predicate does not support keypaths with multiple components")
            }
        case 4: // optional chain
            fatalError("Predicate does not support keypaths with optional chaining/unwrapping")
        default: // unknown keypath component
            fatalError("Predicate does not support this type of keypath (\(firstComponentHeader._keyPathComponentHeader_kind))")
        }
    }
}
