# UUID Version Support and Other Enhancements

* Proposal: [SF-NNNN](NNNN-uuid-versions.md)
* Authors: [Tony Parker](https://github.com/parkera)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#NNNNN](https://github.com/swiftlang/swift-foundation/pull/1836)
* Review: ([pitch](https://forums.swift.org/t/pitch-uuid-v7-other-improvements/85427))

## Introduction

Foundation's `UUID` type currently generates only version 4 (random) UUIDs. [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562) defines several UUID versions, each suited to different use cases. This proposal adds support for creating UUIDs of version 7 (time-ordered) which has become widely adopted for database keys and distributed systems due to its monotonically increasing, sortable nature.

In addition, `UUID` is in need of a few more additions for modern usage, including support for lowercase strings, access to the bytes using `Span`, and accessors for the commonly used `min` and `max` sentinel values.

## Motivation

UUID version 4 (random) is a good general-purpose identifier, but its randomness makes it poorly suited as a database primary key — inserts into B-tree indexes are scattered across the keyspace, leading to poor cache locality and increased write amplification. UUID version 7 addresses this by encoding a Unix timestamp in the most significant 48 bits, producing UUIDs that are monotonically increasing over time while retaining sufficient randomness for uniqueness.

Today, developers who need time-ordered UUIDs usually construct the bytes manually using `UUID(uuid:)`, which is error-prone and requires understanding the RFC 9562 bit layout, or depend on another library. Foundation should provide a straightforward way to create version 7 UUIDs, and a general mechanism for version introspection that accommodates other UUID versions, even if we do not generate them in `UUID` itself.

## Proposed solution

Add a `version` property on `UUID` for introspection, a static factory method for creating version 7 UUIDs, and convenience properties for the nil (which we name `min` to avoid confusion in Swift) and max UUIDs.

```swift
// Create a version 7 UUID
let id = UUID.version7()

// Inspect the version of any UUID
switch id.version {
case 7:
    print("v7 UUID, sortable by creation time")
case 4:
    print("v4 UUID")
default:
    print("other version")
}

// The existing init() continues to create version 4 UUIDs
let randomID = UUID()
assert(randomID.version == 4)

// Min and max UUIDs for sentinel values
let minID = UUID.min   // 00000000-0000-0000-0000-000000000000
let maxID = UUID.max   // FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF

// Access the raw bytes without copying
let uuid = UUID()
let span: Span<UInt8> = uuid.span      // 16-element typed span
```

## Detailed design

### Min and Max UUIDs

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// The minimum UUID, where all 128 bits are set to zero, as defined by
    /// RFC 9562 Section 5.9. Can be used to represent the absence of a
    /// UUID value.
    public static let min: UUID

    /// The max UUID, where all 128 bits are set to one, as defined by
    /// RFC 9562 Section 5.10. Can be used as a sentinel value, for example
    /// to represent "the largest possible UUID" in a sorted range.
    public static let max: UUID
}
```

The min UUID (`00000000-0000-0000-0000-000000000000`) and max UUID (`FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF`) are special forms defined by RFC 9562. They are useful as sentinel values — for example, representing "no UUID" or defining the bounds of a UUID range. Note that neither the min UUID nor the max UUID has a meaningful version or variant field; the `version` property returns `0` and `15` respectively.

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

This initializer provides a safe, typed-throw-compatible way to construct a UUID from bytes without going through `uuid_t`:

```swift
let uuid = UUID { output in
    // Note: It is up to the custom implementation here to create a valid UUID.
    output.append(...)
    output.append(...)
}
```

The closure receives an `OutputSpan<UInt8>` backed by the UUID's 16-byte storage. If the closure writes fewer or more than 16 bytes, the initializer traps. If the closure throws, the error is propagated with its original type.

### `version` and `variant` properties

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// The variant of a UUID, as defined by RFC 9562 Section 4.1.
    public enum Variant: Sendable, Hashable {
        /// NCS backward compatibility (variant bits `0xx`).
        case ncs

        /// The variant specified by RFC 9562 (variant bits `10x`).
        case rfc9562

        /// Microsoft backward compatibility (variant bits `110`).
        case microsoft

        /// Reserved for future use (variant bits `111`).
        case reserved
    }

    /// The version of this UUID, derived from the version bits (bits 48–51) as defined by RFC 9562.
    public var version: Int { get set }

    /// The variant of this UUID, derived from the variant bits (bits 64–65) as defined by RFC 9562.
    public var variant: Variant { get }
}
```

The version value is encoded in bits 48–51 of the UUID (the high nibble of byte 6), per RFC 9562. The returned `Int` ranges from 0 to 15. Well-known versions include 1 (time-based), 3 (name-based MD5), 4 (random), 5 (name-based SHA-1), 6 (reordered time-based), 7 (time-ordered), and 8 (custom). The setter replaces only the version nibble, preserving all other bits.

The variant value is encoded in the high bits of byte 8 (bits 64–65). UUIDs created by Foundation use the RFC 9562 variant (`.rfc9562`, binary `10`). The `Variant` enum covers all four variant values defined by RFC 9562.

### Creating version 4 and version 7 UUIDs

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// Creates a new UUID with RFC 9562 version 4 (random) layout. This is equivalent to calling `UUID()`.
    public static func version4() -> UUID

    /// Creates a new UUID with RFC 9562 version 7 layout: a Unix timestamp in milliseconds in the most significant 48 bits, followed by random bits. The variant and version fields are set per the RFC.
    ///
    /// Version 7 UUIDs sort in chronological order when compared using the standard `<` operator, making them well-suited as database primary keys. UUIDs generated within the same process are guaranteed to be monotonically increasing.
    ///
    /// - Parameter date: The date to encode in the timestamp field. If `nil`, the current time is used. When provided, the monotonicity guarantee does not apply.
    /// - Parameter offset: A duration to add to the timestamp before encoding. Defaults to zero. If `date` is provided, it will be added to the value of that argument.
    public static func version7(at date: Date? = nil, offset: Duration = .zero) -> UUID

    /// Creates a new UUID with RFC 9562 version 7 layout using the specified random number generator for the random bits.
    ///
    /// When called without an `at` argument, the timestamp portion is guaranteed to be monotonically increasing within the current process.
    ///
    /// - Parameter generator: The random number generator to use when creating the random portions of the UUID.
    /// - Parameter date: The date to encode in the timestamp field. If `nil`, the current time is used. When provided, the monotonicity guarantee does not apply.
    /// - Parameter offset: A duration to add to the timestamp before encoding. Defaults to zero. If `date` is provided, it will be added to the value of that argument.
    /// - Returns: A version 7 UUID.
    public static func version7(
        using generator: inout some RandomNumberGenerator,
        at date: Date? = nil,
        offset: Duration = .zero
    ) -> UUID
}
```

The most significant 48 bits contain a millisecond-precision Unix timestamp. The 12 bits following the version field (`rand_a`) encode sub-millisecond timestamp precision per RFC 9562 Section 6.2, Method 3. The remaining 62 bits (`rand_b`, after the variant field) are filled using `generator`. The `version7()` convenience delegates to `version7(using:)` with a `SystemRandomNumberGenerator`.

When called without a `Date` argument, the combined timestamp (milliseconds + sub-millisecond precision) is guaranteed to be monotonically increasing within the current process. An atomic value tracks the last returned timestamp; if the system clock has not advanced since the previous call, the value is incremented by one sub-millisecond tick. This ensures strict ordering even under high-frequency generation or clock adjustments, following the same approach used by Go's `google/uuid` and PostgreSQL. When a caller provides an explicit `date`, the monotonicity guarantee does not apply.

### Extracting the date

```swift
@available(FoundationPreview 6.4, *)
extension UUID {
    /// For version 7 UUIDs, returns the `Date` encoded in the most significant 48 bits. Returns `nil` for all other versions.
    ///
    /// The returned date has millisecond precision, as specified by RFC 9562.
    ///
    /// - Note: Even though this implementation, or others, may choose to encode more precision into other bytes of the `UUID`, this method may only return the portion of the timestamp stored in the RFC-specified bytes.
    public var date: Date? {
        get
    }
}
```

## Source compatibility

This proposal is purely additive. The existing `UUID()` initializer continues to create version 4 random UUIDs. The `random(using:)` static method is unaffected. No existing behavior changes.

UUIDs created by `version7()` are fully valid UUIDs and interoperate with all existing APIs that accept `UUID` or `NSUUID`, including `Codable`, `Comparable`, bridging, and string serialization.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Future directions

- **Version 5 (name-based SHA-1)**: A factory method like `UUID.nameBased(name:namespace:)` could be added in a future proposal for deterministic UUID generation.
- **Version 8 (custom)**: Could be exposed via an initializer that accepts the custom data bits while setting the version and variant fields automatically. For now, we do provide an initializer that allows for setting all of the bytes directly via `OutputSpan`.

## Alternatives considered

### Adding version as a parameter to `init()`

Instead of `UUID.version7()`, we considered `UUID(version: 7)`. However, different versions require different parameters — version 5 needs a name and namespace, version 8 needs custom data — so a single initializer would either need to accept many optional parameters or use an associated-value enum. Static factory methods are clearer and allow each version to have its own natural parameter list.

We also considered using an enumeration for each version with associated types for the different parameters. In practice, this doesn't look or act much differently than simply adding functions to `UUID` with the required arguments.

### Supporting all UUID versions immediately

We considered adding factory methods for all versions (1, 3, 5, 6, 7, 8), but the immediate need is version 7. Version 1 (time-based with MAC address) has privacy implications. Versions 3 and 5 require different parameters. Version 6 is a reordering of version 1 and shares its concerns. Version 8 is intentionally application-defined. Starting with version 7 keeps the proposal focused.

### Different types for different versions

We considered adding different types for each version of a UUID. Community feedback suggests that it is rare to need to restrict version at a _type_ level. If this functionality is needed, the `version` property can be checked dynamically at runtime.

### Accepting a `Clock` parameter instead of `Date`

We considered accepting a `Clock` argument to allow callers to inject a custom time source. However, RFC 9562 requires the timestamp to represent [Unix time](https://en.wikipedia.org/wiki/Unix_time) — specifically, the number of milliseconds since the Unix epoch (1 January 1970 UTC). This corresponds to what Swift would call a `UTCClock` (see the [UTCClock pitch](https://forums.swift.org/t/pitch-utcclock/78018)), not an arbitrary clock. A `SuspendingClock` or `ContinuousClock` measures elapsed time since boot, which would produce an incorrect UUID timestamp. Any clock that *does* produce correct results would necessarily be equivalent to `UTCClock`, making the generality unnecessary. Instead, we accept an optional `Date` for callers who need to embed a specific point in time. This matches the convention used across Foundation for representations of time since the Unix epoch.

### Static function names

Many contributors suggested the use of shorter names like `v7`. While this is unlikely to be confusing to readers, the short name feels overly informal. The Swift API guidelines also suggest avoiding abbreviations. 

We considered prefixing the function name with `make`, as the Swift naming guidelines suggest for some factory methods. However, this pattern is actually rare for similar Foundation API. Similar unprefixed API include `Date.now`, `RecurrenceRule` constructors like `.hourly(...)`, `.monthly(...)`, `CocoaError.error(...)`, `URL.temporaryDirectory`, `URL.homeDirectory(forUser: ...)` and more.

### Deprecating `UUID()`

We considered deprecating the no-argument initializer for `UUID`. We believe that this could be counter-productive in the long term, because it can create "deprecation fatigue." This may encourage callers to ignore warnings because they feel somewhat arbitrary, especially when existing code is correct and will continue to work in the future.

For similar reasons, we cannot change the behavior of the current methods to change the case of the string or version of the result. For example, we expect there to be existing code that would break if we change the result of the `uuidString` to be lowercased.
