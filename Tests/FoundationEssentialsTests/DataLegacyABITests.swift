//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@testable import Foundation
import Testing

extension Foundation.Data {
    @_silgen_name("$s10Foundation4DataV15withUnsafeBytesyxxSWKXEKlF")
    func __testable_withUnsafeBytes<R>(body: (UnsafeRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV22withUnsafeMutableBytesyxxSwKXEKlF")
    mutating func __testable_withUnsafeMutableBytes<R>(body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV6append10contentsOfySays5UInt8VG_tF")
    mutating func __testable_append(contentsOf bytes: [UInt8])

    @_silgen_name("$s10Foundation4DataV15replaceSubrange_4withySnySiG_ACtF")
    mutating func __testable_replaceSubrange(_ subrange: Range<Data.Index>, with data: Data)
}

extension Foundation.Data._Representation {
    @_silgen_name("$s10Foundation4DataV15_RepresentationO15withUnsafeBytesyxxSWKXEKlF")
    func __testable_withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV15_RepresentationO22withUnsafeMutableBytesyxxSwKXEKlF")
    mutating func __testable_withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R
}

extension Foundation.Data.InlineData {
    @_silgen_name("$s10Foundation4DataV06InlineB0V15withUnsafeBytesyxxSWKXEKlF")
    func __testable_withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV06InlineB0V22withUnsafeMutableBytesyxxSwKXEKlF")
    mutating func __testable_withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R
}

extension Foundation.Data.InlineSlice {
    @_silgen_name("$s10Foundation4DataV11InlineSliceV15withUnsafeBytesyxxSWKXEKlF")
    func __testable_withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV11InlineSliceV22withUnsafeMutableBytesyxxSwKXEKlF")
    mutating func __testable_withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV11InlineSliceV15reserveCapacityyySiF")
    mutating func __testable_reserveCapacity(_ minimumCapacity: Int)
}

extension Foundation.Data.LargeSlice {
    @_silgen_name("$s10Foundation4DataV10LargeSliceV15withUnsafeBytesyxxSWKXEKlF")
    func __testable_withUnsafeBytes<R>(_: (UnsafeRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV10LargeSliceV22withUnsafeMutableBytesyxxSwKXEKlF")
    mutating func __testable_withUnsafeMutableBytes<R>(_: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation4DataV10LargeSliceV15reserveCapacityyySiF")
    mutating func __testable_reserveCapacity(_ minimumCapacity: Int)
}

extension Foundation.__DataStorage {
    @_silgen_name("$s10Foundation13__DataStorageC15withUnsafeBytes2in5applyxSnySiG_xSWKXEtKlF")
    final func __testable_withUnsafeBytes<R>(in: Range<Int>, apply: (UnsafeRawBufferPointer) throws -> R) throws -> R

    @_silgen_name("$s10Foundation13__DataStorageC22withUnsafeMutableBytes2in5applyxSnySiG_xSwKXEtKlF")
    final func __testable_withUnsafeMutableBytes<R>(in: Range<Int>, apply: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R
}

@Suite("Foundation Legacy ABI")
private final class FoundationLegacyABITests {

    @Test func validateDataLegacyABI() throws {
        var data = Data()

        #expect(data.isEmpty)
        data.__testable_append(contentsOf: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        #expect(data.count == 10)

        let count1 = try data.__testable_withUnsafeBytes { $0.count }
        #expect(data[0] == 0)
        #expect(count1 == Int(10))

        let count2 = try data.__testable_withUnsafeMutableBytes {
            $0[0] = 42
            return Double($0.count)
        }
        #expect(data[0] == 42)
        #expect(count2 == 10.0)

        #expect(data.count == 10)
        data.__testable_replaceSubrange(0..<10, with: Data())
        #expect(data.isEmpty)
    }

    @Test func validateDataRepresentationLegacyABI() throws {
        let data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        var representation = data._representation
        let count3 = try representation.__testable_withUnsafeBytes { UInt32($0.count) }
        #expect(count3 == UInt32(10))

        let count4 = try representation.__testable_withUnsafeMutableBytes {
            $0[1] = 41
            return Float($0.count)
        }
        #expect(representation[1] == 41)
        #expect(count4 == 10.0)
    }

    @Test func validateInlineDataLegacyABI() throws {
        let data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        guard case var .inline(inline) = data._representation else {
            Issue.record("Unexpected representation of `Data`")
            return
        }

        #expect(inline[2] == 2)
        let count5 = try inline.__testable_withUnsafeBytes { Int16($0.count) }
        #expect(count5 == Int16(10))

        let count6 = try inline.__testable_withUnsafeMutableBytes {
            $0[2] = 40
            return $0.count.leadingZeroBitCount
        }
        #expect(inline[2] == 40)
        #expect(count6 == 10.leadingZeroBitCount)
    }

    @Test func validateInlineSliceLegacyABI() throws {
        let data = Data(count: 40)
        guard case var .slice(slice) = data._representation else {
            Issue.record("Unexpected representation of `Data`")
            return
        }

        #expect(slice.count == 40)
        let count7 = try slice.__testable_withUnsafeBytes { $0.count.trailingZeroBitCount }
        #expect(count7 == 40.trailingZeroBitCount)

        let count8 = try slice.__testable_withUnsafeMutableBytes {
            $0[count7] = 37
            return ($0.count, $0.count)
        }
        #expect(count8.0 == 40)

        #expect(slice.capacity < 200)
        slice.__testable_reserveCapacity(200)
        #expect(slice.capacity >= 200)
    }

    @Test func validateDataStorageLegacyABI() throws {
        let data = Data(0..<40)
        let count7 = data.count.trailingZeroBitCount
        guard case let .slice(slice) = data._representation else {
            Issue.record("Unexpected representation of `Data`")
            return
        }

        let storage = slice.storage

        let count9 = try storage.__testable_withUnsafeBytes(in: count7..<40) {
            #expect($0[0] == 3)
            return $0.count
        }
        #expect(count9 == 40-count7)

        let countA = try storage.__testable_withUnsafeMutableBytes(in: count7..<40) {
            $0[0] = 31
            return ($0.count, Double($0.count.leadingZeroBitCount))
        }
        #expect(slice[count7] == 31)
        #expect(countA.0 == 40-count7)
    }
}

extension LargeDataTests {
    @Test func validateLargeSliceLegacyABI() throws {
        let data = Data(repeating: 0, count: largeCount)
        guard case var .large(slice) = data._representation else {
            Issue.record("Unexpected representation of `Data`")
            return
        }

        #expect(slice.count == largeCount)
        let countA = try slice.__testable_withUnsafeBytes { $0.count }
        #expect(countA == largeCount)

        #expect(slice[largeCount/2] == 0)
        let countB = try slice.__testable_withUnsafeMutableBytes {
            $0[largeCount/2] = 10
            return ($0.count, $0.count)
        }
        #expect(slice[largeCount/2] == 10)
        #expect(countB.0 == largeCount)

        #expect(slice.capacity >= largeCount)
        // don't force a reallocation, but do call the ABI function
        slice.__testable_reserveCapacity(200)
    }

}

#endif // DATA_LEGACY_ABI
