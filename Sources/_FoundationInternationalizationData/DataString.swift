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

/// A generated table that holds one kind of data for each locale, such as the date names in `_DateFormatData` or the numbering systems and number symbols in `_LocaleNumberData`.
///
/// A table's rows hold its locales' data as sub-blocks. A sub-block is a run of values that the formatters read together. For example, the 12 abbreviated month names represented by the `MMM` pattern in `_DateFormatData` is a sub-block with 12 values.
package protocol LocaleDataTable {
    /// The text of the table's strings that are longer than 3 bytes.
    static var pool: StaticString { get }
}

extension LocaleDataTable {
    /// Returns the index of `target` in `count` entries sorted by UTF-8 bytes, or nil.
    static func search(_ target: Span<UInt8>, count: Int, _ entry: (Int) -> UInt32) -> Int? {
        var lo = 0
        var hi = count - 1
        while lo <= hi {
            let mid = (lo &+ hi) / 2
            let cmp = DataString<Self>(entry: entry(mid)).compare(target)
            if cmp == 0 { return mid }
            if cmp < 0 { lo = mid &+ 1 } else { hi = mid &- 1 }
        }
        return nil
    }

    static func search(_ target: String, count: Int, _ entry: (Int) -> UInt32) -> Int? {
        search(target.utf8Span.span, count: count, entry)
    }
}

/// Wraps a string from a generated table
package struct DataString<Table: LocaleDataTable> : Sendable {
    let entry: UInt32

    init(entry: UInt32) {
        self.entry = entry
    }

    package var isEmpty: Bool { entry & 0xFF == 0 }

    package func append(to bytes: inout [UInt8]) {
        let count = Int(entry & 0xFF)
        if count <= 3 {
            for i in 0 ..< count {
                bytes.append(UInt8(truncatingIfNeeded: entry >> (8 * (i + 1))))
            }
        } else {
            withUTF8 { utf8 in
                bytes.append(addingCapacity: count) { output in
                    for i in utf8.indices {
                        output.append(utf8[i])
                    }
                }
            }
        }
    }

    package var string: String {
        var bytes: [UInt8] = []
        append(to: &bytes)
        return String(decoding: bytes, as: UTF8.self)
    }

    func withUTF8<R>(_ body: (Span<UInt8>) -> R) -> R {
        let count = Int(entry & 0xFF)
        if count <= 3 {
            let inline: InlineArray<3, UInt8> = [UInt8(truncatingIfNeeded: entry >> 8), UInt8(truncatingIfNeeded: entry >> 16), UInt8(truncatingIfNeeded: entry >> 24)]
            return body(inline.span.extracting(0 ..< count))
        }
        let offset = Int(entry >> 8)
        return Table.pool.withUTF8Buffer { pool in
            body(pool.span.extracting(offset ..< offset + count))
        }
    }

    /// Compares with UTF-8 bytes, in byte order.
    func compare(_ other: Span<UInt8>) -> Int {
        withUTF8 { utf8 in
            let n = min(utf8.count, other.count)
            var i = 0
            while i < n {
                if utf8[i] != other[i] { return utf8[i] < other[i] ? -1 : 1 }
                i &+= 1
            }
            return utf8.count == other.count ? 0 : (utf8.count < other.count ? -1 : 1)
        }
    }
}
