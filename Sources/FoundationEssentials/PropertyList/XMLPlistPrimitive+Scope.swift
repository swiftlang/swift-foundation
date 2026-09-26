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

#if FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))

// Identity of one node in a parsed XML property list in a Copyable form with a map-buffer offset. Reconstitution into a full XMLPlistPrimitive needs both the `XMLPlistMap` and a `RawSpan` over the source bytes, which the caller supplies. They must match the original map and span that the scope was derived from originally.

internal struct XMLPlistPrimitiveScope: Copyable {
    let mapOffset: XMLPlistMapOffset

    init(mapOffset: XMLPlistMapOffset) {
        self.mapOffset = mapOffset
    }

    init(_ primitive: borrowing XMLPlistPrimitive) {
        self.mapOffset = primitive.mapOffset
    }

    /// Sub-scope for a specific child map offset.
    func child(atOffset childOffset: XMLPlistMapOffset) -> XMLPlistPrimitiveScope {
        XMLPlistPrimitiveScope(mapOffset: childOffset)
    }
}

extension XMLPlistPrimitiveScope {
    /// Reconstitute the `XMLPlistPrimitive`.
    @inline(__always)
    borrowing func withReconstituted<R: ~Copyable, E: Error>(
        in map: borrowing XMLPlistMap<UniqueMapRecords>,
        bytes sourceBytes: borrowing RawSpan,
        _ body: (borrowing XMLPlistPrimitive) throws(E) -> R
    ) throws(E) -> R {
        let bytesCopy = copy sourceBytes
        let primitive = XMLPlistPrimitive(map: map, sourceBytes: bytesCopy, mapOffset: mapOffset)
        return try body(primitive)
    }
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
