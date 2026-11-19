//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal import _FoundationCShims

package struct _VarArgs: ~Copyable {
    package enum Argument {
        case integer(Int64)
        case double(Double)
        case pointer(UnsafeRawPointer?)

#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
        case longDouble(Float80)
#endif
    }

    private var box: _stringformatshims_va_list_box

    init(copying args: CVaListPointer) {
        box = _stringformatshims_va_list_box()
        _stringformatshims_va_box_init(&box, args)
    }

    init(copying other: borrowing _VarArgs) {
        box = _stringformatshims_va_list_box()
        withUnsafePointer(to: other.box) { source in
            _stringformatshims_va_box_copy(&box, source)
        }
    }

    deinit {
        _stringformatshims_va_box_end(box)
    }

    mutating func pop(_ type: Int.Type) -> Int {
        Int(_stringformatshims_va_arg_int(&box))
    }

    mutating func pop(_ type: Int64.Type) -> Int64 {
        _stringformatshims_va_arg_int64(&box)
    }

    mutating func pop(_ type: Int32.Type) -> Int32 {
        _stringformatshims_va_arg_int32(&box)
    }

    mutating func pop(_ type: Double.Type) -> Double {
        _stringformatshims_va_arg_double(&box)
    }

#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
    mutating func pop(_ type: Float80.Type) -> Float80 {
        _stringformatshims_va_arg_long_double(&box)
    }
#endif

    mutating func pop(_ type: UnsafeRawPointer?.Type) -> UnsafeRawPointer? {
        _stringformatshims_va_arg_pointer(&box)
    }

    mutating func pop(kind: ParsedFormatSpec.Kind) -> Argument {
        switch kind {
        case .integer(let flags):
            let value = switch flags.size {
            case .char: Int64(Int8(truncatingIfNeeded: pop(Int.self)))
            case .short: Int64(Int16(truncatingIfNeeded: pop(Int.self)))
            case .int: Int64(pop(Int32.self))
            case .long:
                #if _pointerBitWidth(_64)
                pop(Int64.self)
                #elseif _pointerBitWidth(_32)
                Int64(pop(Int32.self))
                #endif
            case .longLong: pop(Int64.self)
            case .longDouble: Int64(pop(Int.self)) // Not a valid format specifier, but CoreFoundation has historically read this as an int
            }
            return .integer(value)
        case .double(let flags):
#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
            if flags.size == .longDouble {
                return .longDouble(pop(Float80.self))
            }
#endif
            return .double(pop(Double.self))
        case .pointer, .object, .unichars, .chars, .pascalChars:
            return .pointer(pop(UnsafeRawPointer?.self))
        case .singleUnichar:
            return .integer(Int64(pop(Int.self)))
        default:
            preconditionFailure("Unexpected format specifier kind \(kind) for argument")
        }
    }
}
