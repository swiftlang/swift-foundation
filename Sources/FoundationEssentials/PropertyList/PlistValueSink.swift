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

#if !hasFeature(Embedded)

// Sinks that read a binary or XML property list into a tree of Swift values.
//
// The values are `String`, `Int` (or `Int64` when the value does not fit in `Int`), `UInt64` (above `Int64.max`), `Double`, `Bool`, `Date`, `Data`, `[any Sendable]` and `[String : any Sendable]`. A null is the string `"$null"` in both formats: a binary property list can have a null marker, and the XML parser reports the string `$null` as a null. A set is an error. A keyed archiver UID is an error, unless `PropertyListValueOptions.makeUID` makes a value for it.

// MARK: - Options

struct PropertyListValueOptions {
    /// Makes the value for a keyed archiver UID. If this is `nil`, a UID is an error.
    var makeUID: ((UInt32) -> any Sendable)?

    init(makeUID: ((UInt32) -> any Sendable)? = nil) {
        self.makeUID = makeUID
    }
}

// MARK: - Entry point

enum PropertyListValueReader {
    /// Read `data` as a binary or XML property list. The text encoding of an XML property list is found from its byte order mark or its XML declaration. `makeFilter` makes the filter that selects the parts to read; it is a closure because the filter is consumed in the branch that uses it.
    ///
    /// Returns `nil` for the value if the data is neither binary nor XML, so that the caller can read it as an OpenStep property list.
    static func read<Filter: ParseEventFilter & ~Copyable>(_ data: Data, options: PropertyListValueOptions, makeFilter: () -> Filter) throws -> (value: (any Sendable)?, format: PropertyListDecoder.PropertyListFormat) {
        try PropertyListDecoder.detectFormatAndConvertEncoding(for: data, binaryPlist: { buffer in
            let value = try buffer.withUnsafeRawPointer { pointer, count in
                let bytes = unsafe RawSpan(_unsafeStart: pointer, byteCount: count)
                let metadata = try BPlistMetadata.parse(from: bytes)
                let top = BPlistPrimitive(metadata: metadata, bplistData: bytes, objectIndex: metadata.topObjectIndex)
                let source = BPlistPrimitiveSource<Filter>(top: top)
                return try IterativeParsingDriver(sink: BPlistValueSink(options: options, objectCount: metadata.numObjects)).run(source: source, filter: makeFilter())
            }
            return (value, .binary)
        }, xml: { buffer in
            let value = try buffer.withUnsafeRawPointer { pointer, count in
                let bytes = unsafe RawSpan(_unsafeStart: pointer, byteCount: count)
                let list = try XMLPropertyList(bytes)
                let source = XMLPlistPrimitiveSource<Filter>(top: list.topLevelPrimitive)
                return try IterativeParsingDriver(sink: XMLPlistValueSink(options: options)).run(source: source, filter: makeFilter())
            }
            return (value, .xml)
        }, openstep: { _ in
            (nil, .openStep)
        })
    }
}

// MARK: - BPlistValueSink

/// Parse event sink that builds Swift values from a binary property list.
struct BPlistValueSink: ParseEventSink, ~Copyable {
    typealias Vocabulary = BPlistVocabulary
    typealias KeyFragment = String
    typealias ValueFragment = any Sendable
    typealias Output = any Sendable

    private let options: PropertyListValueOptions
    private var result: (any Sendable)?

    /// Scalars by object index. A binary property list can refer to one object from many places, and the writers de-duplicate equal values, so this saves a decode for each repeated reference. Containers are not cached, because a filter can select different contents of one container at different key paths. Object indexes are dense, so an array is faster than a dictionary here (no hashing). An index outside the array is not cached.
    private var valueCache: [(any Sendable)?]
    /// Keys by object index. Arrays of dictionaries usually repeat the same keys.
    private var keyCache: [String?]

    init(options: PropertyListValueOptions, objectCount: Int) {
        self.options = options
        valueCache = Array(repeating: nil, count: objectCount)
        keyCache = Array(repeating: nil, count: objectCount)
    }

    // MARK: Leaf events

    mutating func acceptScalar(_ scalar: borrowing BPlistScalar, cacheKey: Int?, into accumulator: inout ParseEventAccumulator<any Sendable>) throws {
        let value: any Sendable
        switch scalar {
        case .bool(let bool):
            value = bool
        case .int(let int):
            value = integerValue(int)
        case .uint(let uint):
            // A binary property list stores an unsigned integer only when it does not fit in a signed one.
            if let signed = Int64(exactly: uint) {
                value = integerValue(signed)
            } else {
                value = uint
            }
        case .real(let real):
            value = real
        case .date(let interval):
            value = Date(timeIntervalSinceReferenceDate: interval)
        case .data(let span):
            value = span.withUnsafeBufferPointer { unsafe Data(buffer: $0) }
        case .uid(let uid):
            guard let makeUID = options.makeUID else {
                throw BPlistError.corruptedValue("UID")
            }
            value = makeUID(uid)
        case .asciiString(let bytes, _):
            value = try Self.string(fromASCII: bytes)
        case .utf16String(let bytes, _):
            value = Self.string(fromUTF16BE: bytes)
        }
        if let cacheKey, valueCache.indices.contains(cacheKey), scalar.shouldDeduplicateInstancesForMutableLeaves(false) {
            valueCache[cacheKey] = value
        }
        accumulator.append(value)
    }

    mutating func acceptKey(_ keyView: borrowing BPlistKeyView, into accumulator: inout ParseEventAccumulator<String>) throws {
        let objectIndex = keyView.objectIndex
        let isCacheable = keyCache.indices.contains(objectIndex)
        if isCacheable, let cached = keyCache[objectIndex] {
            accumulator.append(cached)
            return
        }
        let key = switch keyView {
        case .asciiString(let bytes, _):
            try Self.string(fromASCII: bytes)
        case .utf16String(let bytes, _):
            Self.string(fromUTF16BE: bytes)
        }
        if isCacheable {
            keyCache[objectIndex] = key
        }
        accumulator.append(key)
    }

    mutating func acceptNull(cacheKey: Int?, into accumulator: inout ParseEventAccumulator<any Sendable>) throws {
        accumulator.append("$null")
    }

    mutating func acceptContainer(_ container: consuming any Sendable, into accumulator: inout ParseEventAccumulator<any Sendable>) throws {
        accumulator.append(container)
    }

    mutating func tryEmitCachedForKey(_ key: Int, into accumulator: inout ParseEventAccumulator<any Sendable>) throws -> Bool {
        guard valueCache.indices.contains(key), let cached = valueCache[key] else {
            return false
        }
        accumulator.append(cached)
        return true
    }

    private func integerValue(_ value: Int64) -> any Sendable {
        // `Int` has 32 bits on some platforms.
        if let int = Int(exactly: value) {
            int
        } else {
            value
        }
    }

    /// Decode a binary ASCII string object as strict UTF-8. Unlike CoreFoundation, which reads each byte as one ISO Latin 1 character, a byte above 0x7F that is not part of valid UTF-8 is an error.
    private static func string(fromASCII bytes: borrowing Span<UInt8>) throws -> String {
        do {
            return String(copying: try UTF8Span(validating: copy bytes))
        } catch {
            throw BPlistError.corruptedValue("string")
        }
    }

    /// Decode a binary UTF-16 string object. CoreFoundation keeps an unpaired surrogate. A `String` cannot hold one, so it becomes U+FFFD.
    private static func string(fromUTF16BE bytes: borrowing Span<UInt8>) -> String {
        bytes.withUnsafeBufferPointer { buffer in
            let unitCount = buffer.count / 2
            return withUnsafeTemporaryAllocation(of: UInt16.self, capacity: unitCount) { units in
                for i in 0 ..< unitCount {
                    units[i] = UInt16(buffer[2 * i]) << 8 | UInt16(buffer[2 * i + 1])
                }
                return String(decoding: units, as: UTF16.self)
            }
        }
    }

    // MARK: Container finalize

    mutating func finalizeUnkeyedContainer(values: borrowing Span<any Sendable>, cacheKey: Int?) throws -> any Sendable {
        Array(copying: values)
    }

    mutating func finalizeUnkeyedContainer(values: borrowing Span<any Sendable>, cacheKey: Int?, kind: BPlistUnkeyedContainerKind) throws -> any Sendable {
        switch kind {
        case .array:
            Array(copying: values)
        case .set:
            throw BPlistError.corruptedValue("set")
        }
    }

    mutating func finalizeKeyedContainer(keys: borrowing Span<String>, values: borrowing Span<any Sendable>, cacheKey: Int?) throws -> any Sendable {
        // The first value for a key wins. This is a loop here, and not `Dictionary(copyingKeys:values:uniquingKeysWith:)`, because that initializer goes through the generic `merge` with a one-element collection, which costs a lot for each key.
        precondition(keys.count == values.count)
        var result = [String : any Sendable](minimumCapacity: keys.count)
        for i in 0 ..< keys.count {
            if let first = result.updateValue(values[i], forKey: keys[i]) {
                result[keys[i]] = first
            }
        }
        return result
    }

    // MARK: Top-level

    mutating func acceptTopLevel(_ value: consuming any Sendable) throws {
        result = value
    }

    consuming func takeResult() throws -> any Sendable {
        guard let result else {
            throw BPlistError.corruptTopLevelInfo
        }
        return result
    }

    func releaseKeyFragment(_ fragment: consuming String) {}
    func releaseValueFragment(_ fragment: consuming any Sendable) {}
}

// MARK: - XMLPlistValueSink

/// Parse event sink that builds Swift values from an XML property list.
struct XMLPlistValueSink: ParseEventSink, ~Copyable {
    typealias Vocabulary = XMLPlistVocabulary
    typealias KeyFragment = String
    typealias ValueFragment = any Sendable
    typealias Output = any Sendable

    private let options: PropertyListValueOptions
    private var result: (any Sendable)?

    init(options: PropertyListValueOptions) {
        self.options = options
    }

    // MARK: Leaf events

    mutating func acceptScalar(_ scalar: borrowing XMLPlistScalar, cacheKey: Int?, into accumulator: inout ParseEventAccumulator<any Sendable>) throws {
        switch scalar {
        case .bool(let value):
            accumulator.append(value)
        case .string(let bytes, let hasEscapes, let source):
            accumulator.append(try _decodeXMLString(from: bytes, isSimple: !hasEscapes, source: source))
        case .integer(let bytes, let source):
            accumulator.append(try Self.integerValue(bytes, source: source))
        case .real(let bytes, let source):
            accumulator.append(try decodeXMLReal(from: bytes, source: source) as Double)
        case .date(let bytes, let source):
            accumulator.append(try decodeXMLDate(from: bytes, source: source))
        case .data(let bytes, let source):
            let maximumCount = xmlDataDecodedMaxCount(from: bytes)
            let bytesCopy = copy bytes
            accumulator.append(try Data(capacity: maximumCount) { output throws in
                try decodeXMLData(from: bytesCopy, into: &output, source: source)
            })
        case .uid(let bytes, let source):
            guard let makeUID = options.makeUID else {
                throw XMLPlistError.corruptedValue("UID")
            }
            guard let raw = try? decodeXMLInteger(from: bytes, source: source) as UInt64, let uid = UInt32(exactly: raw) else {
                throw XMLPlistError.corruptedValue("UID")
            }
            accumulator.append(makeUID(uid))
        }
    }

    mutating func acceptKey(_ keyView: borrowing XMLPlistKeyView, into accumulator: inout ParseEventAccumulator<String>) throws {
        accumulator.append(try _decodeXMLString(from: keyView.bytes, isSimple: !keyView.hasEscapes, source: keyView.source))
    }

    mutating func acceptNull(cacheKey: Int?, into accumulator: inout ParseEventAccumulator<any Sendable>) throws {
        // The parser reports the string `$null` as a null. It stays a string, because NSKeyedArchiver writes it as one.
        accumulator.append("$null")
    }

    mutating func acceptContainer(_ container: consuming any Sendable, into accumulator: inout ParseEventAccumulator<any Sendable>) throws {
        accumulator.append(container)
    }

    private static func integerValue(_ bytes: borrowing Span<UInt8>, source: borrowing Span<UInt8>) throws -> any Sendable {
        // Try unsigned first, which accepts values above `Int64.max`.
        if let unsigned = try? decodeXMLInteger(from: bytes, source: source) as UInt64 {
            if let int = Int(exactly: unsigned) {
                return int
            } else if let int64 = Int64(exactly: unsigned) {
                return int64
            } else {
                return unsigned
            }
        }
        let signed = try decodeXMLInteger(from: bytes, source: source) as Int64
        if let int = Int(exactly: signed) {
            return int
        } else {
            return signed
        }
    }

    // MARK: Container finalize

    mutating func finalizeUnkeyedContainer(values: borrowing Span<any Sendable>, cacheKey: Int?) throws -> any Sendable {
        Array(copying: values)
    }

    mutating func finalizeKeyedContainer(keys: borrowing Span<String>, values: borrowing Span<any Sendable>, cacheKey: Int?) throws -> any Sendable {
        // The last value for a key wins.
        Dictionary<String, any Sendable>(copyingKeys: keys, values: values) { _, last in last }
    }

    // MARK: Top-level

    mutating func acceptTopLevel(_ value: consuming any Sendable) throws {
        result = value
    }

    consuming func takeResult() throws -> any Sendable {
        guard let result else {
            throw XMLPlistError.unexpectedEndOfFile()
        }
        return result
    }

    func releaseKeyFragment(_ fragment: consuming String) {}
    func releaseValueFragment(_ fragment: consuming any Sendable) {}
}

#endif // !hasFeature(Embedded)
