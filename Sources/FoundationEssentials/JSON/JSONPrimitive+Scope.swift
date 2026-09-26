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

// Identity of one node in a parsed JSON payload: a map-buffer offset. Copyable, Sendable, no ARC reference. Reconstitution needs both the `JSONMap` and a `RawSpan` over the source bytes, which the caller supplies.

internal struct JSONPrimitiveScope: Copyable, Sendable {
    let mapOffset: Int

    init(mapOffset: Int) {
        self.mapOffset = mapOffset
    }

    init(_ primitive: borrowing JSONPrimitive) {
        self.mapOffset = primitive.mapOffset
    }

    /// Sub-scope for a specific child map offset.
    func child(atOffset childOffset: Int) -> JSONPrimitiveScope {
        JSONPrimitiveScope(mapOffset: childOffset)
    }
    
    static var top: Self {
        .init(mapOffset: 0)
    }
}

extension JSONPrimitiveScope {
    /// Reconstitute the `JSONPrimitive`.
    @inline(__always)
    borrowing func withReconstituted<R: ~Copyable, E: Error>(
        in map: borrowing JSONMap<UniqueMapRecords>,
        bytes jsonBytes: borrowing RawSpan,
        _ body: (borrowing JSONPrimitive) throws(E) -> R
    ) throws(E) -> R {
        let bytesCopy = copy jsonBytes
        let primitive = JSONPrimitive(map: map, jsonBytes: bytesCopy, mapOffset: mapOffset)
        return try body(primitive)
    }
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
