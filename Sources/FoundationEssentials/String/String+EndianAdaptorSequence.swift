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

enum Endianness {
    case little
    case big
    
    init?(_ ns: String.Encoding) {
        switch ns {
        case .utf16, .utf32: return nil
        case .utf16LittleEndian, .utf32LittleEndian: self = .little
        case .utf16BigEndian, .utf32BigEndian: self = .big
        default: fatalError("Unexpected encoding")
        }
    }
    
    static var host: Endianness {
#if _endian(little)
        return .little
#else
        return .big
#endif
    }
}

/// Converts a sequence of UInt8 containing big-endian or little-endian UInt16 elements into host order. 
/// If the bytes contain a BOM and the endianness on initialization is `nil` then it will honor the BOM to swap the bytes if appropriate.
struct UTF16EndianAdaptor<S : Sequence> : Sequence where S.Element == UInt8 {
    typealias Element = UInt16
    
    let underlying: S
    let endianness: Endianness?

    init(_ sequence: S, endianness: Endianness?) {
        underlying = sequence
        self.endianness = endianness
    }
    
    func makeIterator() -> Iterator {
        Iterator(underlying, endianness: endianness)
    }
    
    struct Iterator : IteratorProtocol {
        var i: S.Iterator
        var endianness: Endianness?
        var bomCheck = false
        
        init(_ sequence: S, endianness: Endianness?) {
            i = sequence.makeIterator()
            self.endianness = endianness
        }
        
        func swap(_ b1: UInt8, _ b2: UInt8) -> UInt16 {
            let uint16 = UInt16(b1) | UInt16(b2) << 8
            switch endianness {
            case .little:
                return UInt16(littleEndian: uint16)
            case .none, .big:
                // Historically speaking, Foundation treats an unspecified encoding on decoding (plain .utf16) + no BOM as assuming the input is big endian.
                return UInt16(bigEndian: uint16)
            }
        }
        
        mutating func next() -> UInt16? {
            // First check for the BOM.
            // If the encoding was unspecified (`.utf16`), then we detect the BOM here, specify the encoding, and remove the BOM.
            // If the encoding was specified, and a BOM is present, and it matches, then remove the BOM.
            // If the encoding was specified, and a BOM is present, and it does not match, then all bets are off. Leave the BOM and pass it on to String to deal with.
            if !bomCheck {
                // Only do this once
                bomCheck = true
                                
                guard let bom1 = i.next() else { return nil }
                
                if bom1 == 0xFF || bom1 == 0xFE {
                    // A BOM is probably present.
                    
                    // Check for BOM byte 2
                    guard let bom2 = i.next() else {
                        // Only 1 byte - return nil
                        return nil
                    }
                    
                    if bom1 == 0xFF && bom2 == 0xFE {
                        if endianness == nil || endianness == .little {
                            // 0xFF FE is little endian
                            self.endianness = .little
                            // Continue below, now that we have skipped BOM
                        } else {
                            // Mismatch of BOM and encoding. Pass it on to String.
                            return swap(bom1, bom2)
                        }
                    } else if bom1 == 0xFE && bom2 == 0xFF {
                        if endianness == nil || endianness == .big {
                            // 0xFE FF is big endian
                            self.endianness = .big
                            // Continue below, now that we have skipped BOM
                        } else {
                            // Mismatch of BOM and encoding. Pass it on to String.
                            return swap(bom1, bom2)
                        }
                    } else {
                        // Not a full BOM; just return the UInt16 and let String sort it out
                        return swap(bom1, bom2)
                    }
                } else {
                    // Not a BOM. 
                    // Get 2nd byte and return it
                    guard let b2 = i.next() else { return nil }
                    return swap(bom1, b2)
                }
            }
            
            // Check for end
            guard let b1 = i.next() else { return nil }
            
            // Check for 2nd byte
            guard let b2 = i.next() else { return nil }
            
            return swap(b1, b2)
        }
    }
}

/// Converts a sequence of UInt8 containing big-endian or little-endian UInt32 elements into host order.
/// If the bytes contain a BOM and the endianness on initialization is `nil` then it will honor the BOM to swap the bytes if appropriate.
struct UTF32EndianAdaptor<S : Sequence> : Sequence where S.Element == UInt8 {
    typealias Element = UInt32
    
    let underlying: S
    let endianness: Endianness?

    init(_ sequence: S, endianness: Endianness?) {
        underlying = sequence
        self.endianness = endianness
    }
    
    func makeIterator() -> Iterator {
        Iterator(underlying, endianness: endianness)
    }
    
    struct Iterator : IteratorProtocol {
        var i: S.Iterator
        var endianness: Endianness?
        var bomCheck = false
        
        init(_ sequence: S, endianness: Endianness?) {
            i = sequence.makeIterator()
            self.endianness = endianness
        }
        
        func swap(_ b1: UInt8, _ b2: UInt8, _ b3: UInt8, _ b4: UInt8) -> UInt32 {
            // We use big endianness if none has been specified and no BOM was detected.
            let uint32 = UInt32(b1) | UInt32(b2) << 8 | UInt32(b3) << 16 | UInt32(b4) << 24
            switch endianness {
            case .little:
                return UInt32(littleEndian: uint32)
            case .none, .big:
                return UInt32(bigEndian: uint32)
            }
        }
        
        mutating func next() -> UInt32? {
            // First check for the BOM.
            // If the encoding was unspecified (`.utf32`), then we detect the BOM here, specify the encoding, and remove the BOM.
            // If the encoding was specified, and a BOM is present, and it matches, then remove the BOM.
            // If the encoding was specified, and a BOM is present, and it does not match, then all bets are off. Leave the BOM and pass it on to String to deal with.
            if !bomCheck {
                // Only do this once
                bomCheck = true
                                
                guard let bom1 = i.next() else { return nil }
                
                if bom1 == 0xFF || bom1 == 0x00 {
                    // A BOM is probably present.
                    
                    // Check for remaining BOM bytes
                    guard let bom2 = i.next() else { return nil }
                    guard let bom3 = i.next() else { return nil }
                    guard let bom4 = i.next() else { return nil }

                    if bom1 == 0xFF && bom2 == 0xFE && bom3 == 0x00 && bom4 == 0x00 {
                        if endianness == nil || endianness == .little {
                            // 0xFF FE 00 00 is little endian
                            self.endianness = .little
                            // Continue below, now that we have skipped BOM
                        } else {
                            // Mismatch of BOM and encoding. Pass it on to String.
                            return swap(bom1, bom2, bom3, bom4)
                        }
                    } else if bom1 == 0x00 && bom2 == 0x00 && bom3 == 0xFE && bom4 == 0xFF {
                        if endianness == nil || endianness == .big {
                            // 0x00 00 FE FF is big endian
                            self.endianness = .big
                            // Continue below, now that we have skipped BOM
                        } else {
                            // Mismatch of BOM and encoding. Pass it on to String.
                            return swap(bom1, bom2, bom3, bom4)
                        }
                    } else {
                        // Not a full BOM; just return the UInt16 and let String sort it out
                        return swap(bom1, bom2, bom3, bom4)
                    }
                } else {
                    // Not a BOM. Get remaining bytes and return it
                    guard let b2 = i.next() else { return nil }
                    guard let b3 = i.next() else { return nil }
                    guard let b4 = i.next() else { return nil }
                    return swap(bom1, b2, b3, b4)
                }
            }
            
            // Check for end
            guard let b1 = i.next() else { return nil }
            
            // Check for remaining bytes
            guard let b2 = i.next() else { return nil }
            guard let b3 = i.next() else { return nil }
            guard let b4 = i.next() else { return nil }

            return swap(b1, b2, b3, b4)
        }
    }
}

/// Converts a UTF16View to endian-swapped UInt16 values.
struct UTF16ToDataAdaptor : Sequence {
    typealias Element = UInt8
    typealias S = String.UTF16View
    
    let underlying: S
    let endianness: Endianness

    init(_ sequence: S, endianness: Endianness) {
        underlying = sequence
        self.endianness = endianness
    }
    
    func makeIterator() -> Iterator {
        Iterator(i: underlying.makeIterator(), endianness: endianness)
    }
    
    struct Iterator : IteratorProtocol {
        var u16: UInt16?
        var i: S.Iterator
        var endianness: Endianness
        var done: Bool
        
        init(i: S.Iterator, endianness: Endianness) {
            u16 = nil
            done = false
            self.i = i
            self.endianness = endianness
        }
        
        mutating func next() -> Element? {
            guard !done else { return nil }
            
            if var u16 {
                // We have a value already, return second byte
                self.u16 = nil
                return withUnsafeBytes(of: &u16) {
                    $0[1]
                }
            } else {
                if let u16 = i.next() {
                    var value = switch endianness {
                    case .little:
                        u16.littleEndian
                    case .big:
                        u16.bigEndian
                    }
                    self.u16 = value
                    return withUnsafeBytes(of: &value) {
                        $0[0]
                    }
                } else {
                    done = true
                    return nil
                }
            }
        }
    }
}

struct UnicodeScalarToDataAdaptor : Sequence {
    typealias Element = UInt8
    typealias S = String.UnicodeScalarView
    
    let underlying: S
    let endianness: Endianness

    init(_ sequence: S, endianness: Endianness) {
        underlying = sequence
        self.endianness = endianness
    }
    
    func makeIterator() -> Iterator {
        Iterator(i: underlying.makeIterator(), endianness: endianness)
    }
    
    struct Iterator : IteratorProtocol {
        var u32: UInt32
        var nextByte = 0
        var i: S.Iterator
        var endianness: Endianness
        var done: Bool
        
        init(i: S.Iterator, endianness: Endianness) {
            u32 = 0
            done = false
            self.i = i
            self.endianness = endianness
        }
        
        mutating func next() -> Element? {
            guard !done else { return nil }
            
            if nextByte > 0 {
                // We have a value already, return next byte
                let result = withUnsafeBytes(of: &u32) {
                    $0[nextByte]
                }

                nextByte += 1
                if nextByte == 4 {
                    nextByte = 0
                }
                return result
            } else {
                guard let u32 = i.next() else {
                    done = true
                    return nil
                }
                
                var value = switch endianness {
                case .little:
                    u32.value.littleEndian
                case .big:
                    u32.value.bigEndian
                }
                
                self.u32 = value
                nextByte = 1
                return withUnsafeBytes(of: &value) {
                    $0[0]
                }
            }
        }
    }
}
