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

// Event alphabets (`ParseEventVocabulary` conformers) shared by each format's `ParseEventSource` and `ParseEventSink`. The primitive-decoder path in FoundationPreview and the framework tree-sink path both drive `IterativeParsingDriver` with the same vocabulary types.

// MARK: - JSON

enum JSONScalar: ~Copyable, ~Escapable {
    case bool(Bool)
    /// `hasEscapes == false` means the byte range is directly usable UTF-8.
    case string(bytes: Span<UInt8>, hasEscapes: Bool, source: Span<UInt8>)
    /// `containsExponent == true` skips the integer-parse fast path in the decoder.
    case number(bytes: Span<UInt8>, containsExponent: Bool, source: Span<UInt8>)
}

struct JSONKeyView: ~Copyable, ~Escapable {
    let bytes: Span<UInt8>
    let hasEscapes: Bool
    let source: Span<UInt8>

    @_lifetime(copy bytes, copy source)
    init(bytes: Span<UInt8>, hasEscapes: Bool, source: Span<UInt8>) {
        self.bytes = bytes
        self.hasEscapes = hasEscapes
        self.source = source
    }
}

/// Event alphabet shared by JSON sources and sinks.
enum JSONVocabulary: ParseEventVocabulary {
    typealias Scalar = JSONScalar
    typealias KeyView = JSONKeyView
}

// MARK: - XML plist

enum XMLPlistScalar: ~Copyable, ~Escapable {
    case bool(Bool)
    /// `hasEscapes == false` means source bytes are already usable UTF-8 (scanner's `.simpleString`).
    case string(bytes: Span<UInt8>, hasEscapes: Bool, source: Span<UInt8>)
    /// Base-10 ASCII digits (with optional leading sign for signed values). Sink parses at accept time.
    case integer(bytes: Span<UInt8>, source: Span<UInt8>)
    /// Textual real / floating-point ASCII bytes.
    case real(bytes: Span<UInt8>, source: Span<UInt8>)
    /// ISO-8601-ish date bytes.
    case date(bytes: Span<UInt8>, source: Span<UInt8>)
    /// Base-64 ASCII bytes.
    case data(bytes: Span<UInt8>, source: Span<UInt8>)
    /// A CFKeyedArchiverUID leaf. Emitted by sources reading a map that already has a native UID record; fresh parses see the `{"CF$UID": N}` dict shape instead and detect it at `finalizeKeyedContainer`.
    case uid(bytes: Span<UInt8>, source: Span<UInt8>)
}

struct XMLPlistKeyView: ~Copyable, ~Escapable {
    let bytes: Span<UInt8>
    let hasEscapes: Bool
    let source: Span<UInt8>

    @_lifetime(copy bytes, copy source)
    init(bytes: Span<UInt8>, hasEscapes: Bool, source: Span<UInt8>) {
        self.bytes = bytes
        self.hasEscapes = hasEscapes
        self.source = source
    }
}

/// Event alphabet shared by XML plist sources and sinks.
enum XMLPlistVocabulary: ParseEventVocabulary {
    typealias Scalar = XMLPlistScalar
    typealias KeyView = XMLPlistKeyView
}

// MARK: - Deriving positions from a scalar's `source`

extension Span<UInt8> {
    /// The byte range `bytes` occupies within `self`. Carries the presumption that `self` does contain `bytes`.
    @inline(__always)
    func sourceByteRange(of bytes: borrowing Span<UInt8>) -> Range<Int> {
        guard let indices = indices(of: bytes) else {
            preconditionFailure("value span is not a subrange of the document it was emitted with")
        }
        return indices
    }

    /// The byte offset at which `bytes` begins within `self`. Carries the presumption that `self` does contain `bytes`.
    @inline(__always)
    func sourceByteOffset(of bytes: borrowing Span<UInt8>) -> Int {
        sourceByteRange(of: bytes).lowerBound
    }

    /// True when `bytes` runs to the very end of `self`, meaning there is no byte after it in the document. Carries the presumption that `self` does contain `bytes`.
    @inline(__always)
    func spanIsTerminated(by bytes: borrowing Span<UInt8>) -> Bool {
        sourceByteRange(of: bytes).upperBound == count
    }
}

// MARK: - Binary plist

enum BPlistScalar: ~Copyable, ~Escapable {
    case bool(Bool)
    case int(Int64)
    case uint(UInt64)
    case real(Double)
    /// bplist stores dates as CFAbsoluteTime doubles.
    case date(Double)
    /// A `Span` over bplist bytes.
    case data(Span<UInt8>)
    /// A CFKeyedArchiverUID leaf.
    case uid(UInt32)
    /// ASCII string bytes (bplist's 0x5X marker). No escapes.
    /// `objectOffset`: bplist record offset for the mapped-string SPI: when the sink has a `backingData`, a heap-allocated result gets replaced with `_NSBPlistMappedString(objectOffset:mappedData:)` for zero-copy backing + embedded-NUL preservation.
    case asciiString(bytes: Span<UInt8>, objectOffset: Int)
    /// UTF-16BE string bytes (bplist's 0x6X marker). See `asciiString` for `objectOffset`.
    case utf16String(bytes: Span<UInt8>, objectOffset: Int)
}

enum BPlistKeyView: ~Copyable, ~Escapable {
    case asciiString(Span<UInt8>)
    case utf16String(Span<UInt8>)
}

/// Which unkeyed container a bplist frame represents. Arrays (0xA_) and sets (0xC_) share the same on-disk ref-list shape and the same walk, so the source carries this to tell a sink which to materialize at finalize.
enum BPlistUnkeyedContainerKind {
    case array
    case set
}

/// Event alphabet shared by bplist sources and sinks.
enum BPlistVocabulary: ParseEventVocabulary {
    typealias Scalar = BPlistScalar
    typealias KeyView = BPlistKeyView
    typealias UnkeyedContainerKind = BPlistUnkeyedContainerKind
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
