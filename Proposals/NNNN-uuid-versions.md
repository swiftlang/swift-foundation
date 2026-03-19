# UUID Version Support and Other Enhancements

* Proposal: [SF-NNNN](NNNN-uuid-versions.md)
* Authors: [Tony Parker](https://github.com/parkera)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#NNNNN](https://github.com/swiftlang/swift-foundation/pull/NNNNN)
* Review: ([pitch](https://forums.swift.org/...))

## Introduction

Foundation's `UUID` type currently generates only version 4 (random) UUIDs. [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562) defines several UUID versions, each suited to different use cases. This proposal adds support for creating UUIDs of version 7 (time-ordered) which has become widely adopted for database keys and distributed systems due to its monotonically increasing, sortable nature.

In addition, `UUID` is in need of a few more additions for modern usage, including support for lowercase strings, access to the bytes using `Span`, and accessors for the commonly used `nil` and `max` sentinel values.

## Motivation

UUID version 4 (random) is a good general-purpose identifier, but its randomness makes it poorly suited as a database primary key — inserts into B-tree indexes are scattered across the keyspace, leading to poor cache locality and increased write amplification. UUID version 7 addresses this by encoding a Unix timestamp in the most significant 48 bits, producing UUIDs that are monotonically increasing over time while retaining sufficient randomness for uniqueness.

Today, developers who need time-ordered UUIDs usually construct the bytes manually using `UUID(uuid:)`, which is error-prone and requires understanding the RFC 9562 bit layout, or depend on another library. Foundation should provide a straightforward way to create version 7 UUIDs, and a general mechanism for version introspection that accommodates other UUID versions, even if we do not generate them in `UUID` itself.

## Proposed solution

Add a `UUID.Version` struct representing the well-known UUID versions from RFC 9562, a `version` property on `UUID` for introspection, a static factory method for creating version 7 UUIDs, and convenience properties for the nil and max UUIDs.

```swift
// Create a time-ordered UUID
let id = UUID.timeOrdered()

// Inspect the version of any UUID
switch id.version {
case .timeOrdered:
    print("v7 UUID, sortable by creation time")
case .random:
    print("v4 UUID")
default:
    print("other version")
}

// The existing init() continues to create version 4 UUIDs
let randomID = UUID()
assert(randomID.version == .random)

// Nil and max UUIDs for sentinel values
let nilID = UUID.nil   // 00000000-0000-0000-0000-000000000000
let maxID = UUID.max   // FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF

// Access the raw bytes without copying
let uuid = UUID()
let span: Span<UInt8> = uuid.span      // 16-element typed span
```

## Detailed design

### Nil and Max UUIDs

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// The nil UUID, where all 128 bits are set to zero, as defined by
    /// RFC 9562 Section 5.9. Can be used to represent the absence of a
    /// UUID value.
    public static let `nil`: UUID

    /// The max UUID, where all 128 bits are set to one, as defined by
    /// RFC 9562 Section 5.10. Can be used as a sentinel value, for example
    /// to represent "the largest possible UUID" in a sorted range.
    public static let max: UUID
}
```

The nil UUID (`00000000-0000-0000-0000-000000000000`) and max UUID (`FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF`) are special forms defined by RFC 9562. They are useful as sentinel values — for example, representing "no UUID" or defining the bounds of a UUID range. Note that neither the nil UUID nor the max UUID has a meaningful version or variant field; the `version` property returns `Version(rawValue: 0)` and `Version(rawValue: 15)` respectively.

### Lowercase string representation

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// Returns a lowercase string created from the UUID, such as
    /// "e621e1f8-c36c-495a-93fc-0c247a3e6e5f".
    public var lowercasedUUIDString: String { get }
}
```

The existing `uuidString` property returns an uppercase representation. Many systems — including web APIs, databases, and URN formatting (RFC 4122 §3) — conventionally use lowercase UUIDs. `lowercasedUUIDString` avoids the need to call `uuidString.lowercased()`, which allocates an intermediate `String`.

### `span` and `mutableSpan` properties

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// A `Span<UInt8>` view of the UUID's 16 bytes.
    public var span: Span<UInt8> { get }

    /// A `MutableSpan<UInt8>` view of the UUID's 16 bytes.
    public var mutableSpan: MutableSpan<UInt8> { mutating get }
}
```

These properties provide bounds-checked access to the UUID's bytes without the need for `withUnsafeBytes` or tuple element access. `span` provides read-only access; `mutableSpan` allows direct modification of the underlying bytes. Both are lifetime-dependent on the UUID value.

### Initializing from a `Span`

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// Creates a UUID by copying exactly 16 bytes from a `Span<UInt8>`.
    public init(copying span: Span<UInt8>)
}
```

This initializer copies the bytes from a `Span<UInt8>` into a new UUID. The span must contain exactly 16 bytes; otherwise, the initializer traps.

### Initializing from an `OutputSpan`

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// Creates a UUID by filling its 16 bytes using a closure that
    /// writes into an `OutputSpan<UInt8>`.
    ///
    /// The closure must write exactly 16 bytes into the output span.
    public init<E: Error>(
        initializingWith initializer: (inout OutputSpan<UInt8>) throws(E) -> ()
    ) throws(E)
}
```

This initializer provides a safe, typed-throw-compatible way to construct a UUID from raw bytes without going through `uuid_t`:

```swift
let uuid = UUID { output in
    output.append(timestampBytes)
    output.append(randomBytes)
}
```

The closure receives an `OutputSpan<UInt8>` backed by the UUID's 16-byte storage. If the closure writes fewer or more than 16 bytes, the initializer traps. If the closure throws, the error is propagated with its original type.

### `UUID.Version`

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// The version of a UUID, as defined by RFC 9562.
    public struct Version: Sendable, Hashable, Codable, RawRepresentable {
        public let rawValue: UInt8
        public init(rawValue: UInt8)

        /// Version 1: Gregorian time-based UUID with node identifier.
        public static var timeBased: Version { get }

        /// Version 3: Name-based UUID using MD5 hashing.
        public static var nameBasedMD5: Version { get }

        /// Version 4: Random UUID.
        public static var random: Version { get }

        /// Version 5: Name-based UUID using SHA-1 hashing.
        public static var nameBasedSHA1: Version { get }

        /// Version 6: Reordered Gregorian time-based UUID.
        public static var reorderedTimeBased: Version { get }

        /// Version 7: Unix Epoch time-based UUID with random bits.
        public static var timeOrdered: Version { get }

        /// Version 8: Custom UUID with user-defined layout.
        public static var custom: Version { get }
    }
}
```

The version value is encoded in bits 48–51 of the UUID (the high nibble of byte 6), per RFC 9562. `Version` is a `RawRepresentable` struct rather than an enum, allowing new versions to be added without breaking source or binary compatibility. The well-known versions from RFC 9562 are provided as static properties. Versions 2 (DCE Security), 0 (nil UUID), and 15 (max UUID) do not have static properties but can be represented using `Version(rawValue:)` if needed.

### `version` property

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// The version of this UUID, derived from the version bits
    /// (bits 48–51) as defined by RFC 9562.
    public var version: UUID.Version {
        get
    }
}
```

### Creating version 7 UUIDs

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// Creates a new UUID with RFC 9562 version 7 layout: a Unix
    /// timestamp in milliseconds in the most significant 48 bits,
    /// followed by random bits. The variant and version fields are
    /// set per the RFC.
    ///
    /// Version 7 UUIDs sort in approximate chronological order
    /// when compared using the standard `<` operator, making them
    /// well-suited as database primary keys. UUIDs created within
    /// the same millisecond are distinguished by random bits and
    /// may not reflect exact creation order.
    public static func timeOrdered() -> UUID

    /// Creates a new UUID with RFC 9562 version 7 layout using
    /// the specified random number generator for the random bits.
    ///
    /// - Parameter generator: The random number generator to use
    ///   when creating the random portions of the UUID.
    /// - Returns: A version 7 UUID.
    public static func timeOrdered(
        using generator: inout some RandomNumberGenerator
    ) -> UUID
}
```

The resulting UUID contains a millisecond-precision Unix timestamp in bits 0–47, with version and variant fields set per RFC 9562. The remaining bits are filled using the system random number generator (for `timeOrdered()`) or the provided generator (for `timeOrdered(using:)`). The `timeOrdered()` convenience delegates to `timeOrdered(using:)` with a `SystemRandomNumberGenerator`.

### Extracting the timestamp

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// For version 7 UUIDs, returns the `Date` encoded in the
    /// most significant 48 bits. Returns `nil` for all other versions.
    /// The returned date has millisecond precision, as specified
    /// by RFC 9562.
    public var timeOrderedTimestamp: Date? {
        get
    }
}
```

## Source compatibility

This proposal is purely additive. The existing `UUID()` initializer continues to create version 4 random UUIDs. The `random(using:)` static method is unaffected. No existing behavior changes.

UUIDs created by `timeOrdered()` are fully valid UUIDs and interoperate with all existing APIs that accept `UUID` or `NSUUID`, including `Codable`, `Comparable`, bridging, and string serialization.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Future directions

- **Version 5 (name-based SHA-1)**: A factory method like `UUID.nameBased(name:namespace:)` could be added in a future proposal for deterministic UUID generation.
- **Version 8 (custom)**: Could be exposed via an initializer that accepts the custom data bits while setting the version and variant fields automatically. For now, we do provide an initializer that allows for setting all of the bytes directly via `OutputSpan`.

## Alternatives considered

### Adding version as a parameter to `init()`

Instead of `UUID.timeOrdered()`, we considered `UUID(version: .timeOrdered)`. However, different versions require different parameters — version 5 needs a name and namespace, version 8 needs custom data — so a single initializer would either need to accept many optional parameters or use an associated-value enum. Static factory methods are clearer and allow each version to have its own natural parameter list.

### Using an `enum` for `Version`

We considered making `Version` an `enum` with a `UInt8` raw value. However, a `struct` with `RawRepresentable` conformance allows new versions to be added in the future without breaking source or binary compatibility. Since the UUID version field is only 4 bits, the full space of 16 values is defined by the RFC, but using a struct is more consistent with Foundation's conventions for open sets of values (e.g., `NSNotificationName`, `RunLoop.Mode`) and avoids the need for an `unknown` case or optional return from the `version` property.

### Supporting all UUID versions immediately

We considered adding factory methods for all versions (1, 3, 5, 6, 7, 8), but the immediate need is version 7. Version 1 (time-based with MAC address) has privacy implications. Versions 3 and 5 require different parameters. Version 6 is a reordering of version 1 and shares its concerns. Version 8 is intentionally application-defined. Starting with version 7 keeps the proposal focused while the `Version` struct provides the foundation to add others incrementally.
