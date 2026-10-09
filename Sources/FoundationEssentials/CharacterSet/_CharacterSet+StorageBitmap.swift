//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension _CharacterSet {
    struct BitmapBacked {
        var data: Data
        
        init(data: Data) {
            // Data(init:) is needed for built-in set initialized via `init(bytesNoCopy:)`
            self.data = Data(data)
        }
        
        internal var span: Span<UInt8> {
            return data.span
        }
        
        internal var mutableSpan: MutableSpan<UInt8> {
            mutating get {
                return data.mutableSpan
            }
        }
        
        internal var isEmpty: Bool {
            let currentSpan = span
            if currentSpan.isEmpty {
                return true
            }
            
            return _CharacterSet.bytes(of: currentSpan, equalTo: 0x00)
        }
        
        // __CFCSetIsMemberBitmap
        internal func contains(_ member: Unicode.Scalar) -> Bool {
            return _contains(codepoint: Int(member.value))
        }

        // Surrogate code units (0xD800-0xDFFF) are not representable as Unicode.Scalar,
        // so callers pass the raw value here.
        internal func contains(surrogate codepoint: UInt16) -> Bool {
            return _contains(codepoint: Int(codepoint))
        }

        private func _contains(codepoint: Int) -> Bool {
            let currentSpan = span
            guard !currentSpan.isEmpty else {
                return false
            }
            
            let byteIndex = codepoint >> _CharacterSet.LOG_BPB
            guard byteIndex < currentSpan.count else { return false }
            
            let bitMask = UInt8(1 << (codepoint & (_CharacterSet.BITSPERBYTE - 1)))
            
            return (currentSpan[byteIndex] & bitMask) != 0
        }
        
        internal mutating func invert() {
            if span.isEmpty {
                data = _CharacterSet.allOnes()
            } else {
                var mutableSpan = data.mutableSpan
                for i in 0..<mutableSpan.count {
                    mutableSpan[i] = ~mutableSpan[i]
                }
            }
        }
        
        internal func hasMemberInBMPPlane() -> Bool {
            return !isEmpty
        }
        
        internal func annexHasMember(annexIsInverted: Bool) -> Bool {
            let currentSpan = span
            if annexIsInverted {
                // Return true if there's any 0 byte (i.e., not all ones)
                return !_CharacterSet.bytes(of: currentSpan, equalTo: 0xFF)
            } else {
                // Return true if there's any non-zero byte (i.e., not all zeros)
                return !_CharacterSet.bytes(of: currentSpan, equalTo: 0x00)
            }
        }
    }
}
