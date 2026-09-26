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

// MARK: - BPlistPrimitiveScope

/// The pure identity of a single object in a parsed binary property list: its owning `BPlistMetadata` (by value) plus its `ValidatedBPlistObjectIndex`. To reconstitute the `BPlistPrimitive`, the caller supplies a `RawSpan` over the same byte range that produced `metadata`.
///
///     let span: RawSpan = ...
///     scope.withReconstituted(in: span) { primitive in
///         // ... read fields off `primitive` ...
///     }
struct BPlistPrimitiveScope: Copyable, Sendable {
    let metadata: BPlistMetadata
    let objectIndex: ValidatedBPlistObjectIndex

    init(_ primitive: borrowing BPlistPrimitive) {
        self.metadata = primitive.metadata
        self.objectIndex = primitive.objectIndex
    }

    init(metadata: BPlistMetadata, objectIndex: ValidatedBPlistObjectIndex) {
        self.metadata = metadata
        self.objectIndex = objectIndex
    }

    /// Sub-scope for a specific child object index, relative to the same `BPlistMetadata`.
    func child(at childIndex: ValidatedBPlistObjectIndex) -> BPlistPrimitiveScope {
        BPlistPrimitiveScope(metadata: metadata, objectIndex: childIndex)
    }
}

extension BPlistPrimitiveScope {
    borrowing func withReconstituted<R: ~Copyable, E: Error>(
        in bplistData: borrowing RawSpan,
        _ body: (borrowing BPlistPrimitive) throws(E) -> R
    ) throws(E) -> R {
        let dataCopy = copy bplistData
        let primitive = BPlistPrimitive(metadata: metadata,
                                        bplistData: dataCopy,
                                        objectIndex: objectIndex)
        return try body(primitive)
    }
}
