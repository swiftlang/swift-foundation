# Embedded Swift Skip List — swift-foundation

Types in swift-foundation that are **NOT portable to Embedded Swift** and the reason why.
This is the Phase-1 research output for the effort to build swift-foundation (specifically
`FoundationEssentials`) in Embedded Swift mode.

> **Sources:** https://docs.swift.org/embedded/documentation/embedded — subpages
> `LanguageSubset`, `Existentials`, `Status`, `NonFinalGenericMethods`, `Strings`,
> `ConditionalCompilation`. The DocC HTML is JS-rendered; fetch the render JSON via
> `curl https://docs.swift.org/embedded/data/documentation/embedded/<page>.json`.

---

## 0. Which restrictions drive this list

> ⚠️ **The docs contradict each other.** The prose *Language subset* page is stale and lists
> `Any`, metatypes, `any Error`, and non-class-bound existentials as unavailable. The newer
> *Implementation Status* table and *Existentials* page say these are now **supported (with
> restrictions)**. This list trusts the Status table (matches the recently-announced changes).

### Hard blockers (feature genuinely unavailable)
1. **`Codable` / `Encodable` / `Decodable`** and the `Encoder`/`Decoder`/container machinery.
2. **Runtime `KeyPath`** — only compile-time-constant key paths to stored properties, usable only
   in `MemoryLayout`/`UnsafePointer`. `KeyPath` used as a value (stored/passed, `\.foo`,
   `subscript(dynamicMember: KeyPath…)`, `PartialKeyPath`, `AnyKeyPath`) is a blocker.
3. **Parameter packs / variadic generics** (`repeat each`, `each T`) — not yet implemented.
4. **Casting *to* an existential type or existential metatype** (`x as? any P`, `as! any P`,
   `as? (any P).Type`). Also: calling unbounded generics on / "opening" an existential.
   *(Forming an existential by upcasting a concrete value, `concrete as any P`, is allowed.)*
5. **`Mirror` / runtime reflection consumption.** *(Conforming to `CustomReflectable` / providing
   `customMirror` is a droppable conformance — not a blocker.)*
6. **`weak` / `unowned`** references (only `unowned(unsafe)`).
7. **Non-final generic methods on non-final classes.**
8. **`VarArgs`** (`CVarArg` usage, `withVaList`). *(Conforming a type to `CVarArg` is droppable.)*
9. **ObjC interop / bridging**, `InputStream`/`OutputStream`, Library Evolution, non-WMO builds.
   *(Foundation's ObjC bridging is already `#if FOUNDATION_FRAMEWORK`-gated, so it compiles out.)*

### Now SUPPORTED (recently changed — NOT blockers)
Existentials of any protocol (`any P`), `Any`, `AnyObject` (with the cast/open limits above);
metatypes & `type(of:)` (except casting to existential metatypes); untyped `throws`/`any Error`
(⚠️ verify on toolchain — docs disagree); generics, protocols incl. associated & primary
associated types, enums w/ associated values, classes, closures, Set/Dictionary/Array, SIMD,
unsafe pointers, `Atomic`.

### Non-language practical blockers
- **ICU dependency** (`_FoundationICU`) — all of `FoundationInternationalization`.
- **`Mutex`** (Synchronization) — not in embedded yet (only `Atomic`); used in ~45 files.
- **OS / threading / Concurrency runtime** — syscalls, `DispatchQueue`, actors/async pipelines.

---

## 1. NOT PORTABLE — by root cause

### A. `Codable` is the type's entire purpose (cannot just drop a conformance)

| Type | Reason | Evidence |
|---|---|---|
| `JSONEncoder` | Drives `Encodable`; internal `Encoder`/container conformances; casts to existential metatype | `JSON/JSONEncoder.swift:407,455,1282` |
| `JSONDecoder` | Drives `Decodable`; `JSONDecoderImpl: Decoder`; `type as? (…Marker & Decodable).Type` | `JSON/JSONDecoder.swift:579,836,673` |
| `JSONEncoder/Decoder.{Date,Data,Key}{En,De}codingStrategy` | `.custom` cases embed `Encoder`/`Decoder`/`CodingKey` closures | `JSONEncoder.swift:112,172`; `JSONDecoder.swift:99,154` |
| `PropertyListEncoder` | `Encodable` → plist via `Encoder`-conforming impls | `PropertyList/PlistEncoder.swift:107,224` |
| `PropertyListDecoder` | `Decodable` via `_PlistDecoder: Decoder` | `PropertyList/PlistDecoder.swift:91,139` |
| `EncodableWithConfiguration` / `DecodableWithConfiguration` / `CodableWithConfiguration` | Protocols defined entirely by `Encoder`/`Decoder` methods | `CodableWithConfiguration.swift:31,52` |
| `EncodingConfigurationProviding` / `DecodingConfigurationProviding` | Only meaningful as Codable-config hooks | `CodableWithConfiguration.swift:15,36` |
| `CodableConfiguration` (property wrapper) | Body *is* `encode(to:)`/`init(from:)` | `CodableWithConfiguration.swift:210,244,248` |

> No public `JSONValue`/`JSONSerialization` to salvage — value model & errors are `internal`.
> The byte-level scanners/writers ARE feature-clean but `internal` (see §3).

### B. Runtime `KeyPath`

| Type | Reason | Evidence |
|---|---|---|
| `AttributedStringProtocol` | *Requires* `subscript(dynamicMember: KeyPath<AttributeDynamicLookup,K>)` — core, non-droppable | `AttributedStringProtocol.swift:100,104` |
| `AttributeContainer` | `@dynamicMemberLookup` via runtime-KeyPath subscripts is its whole surface | `AttributeContainer.swift:45,57,83` |
| `AttributeDynamicLookup`, `ScopedAttributeContainer`, `AttributeContainer.Builder` | Exist solely as roots/results of KeyPath dynamic-member lookup | `AttributedStringAttribute.swift:169,188`; `AttributeContainer.swift:83` |
| `SortDescriptor` | Enum cases store `KeyPath<Compared,…>`; `lhs[keyPath: kp]` | `String/SortDescriptor.swift:23,29,1117` |
| `KeyPathComparator` | Stores/consumes runtime `PartialKeyPath<Compared>` | `String/KeyPathComparator.swift:22,42` |
| `ProgressManager`, `ProgressReporter` | `@Observable` + `@dynamicMemberLookup` → runtime-KeyPath access; also `weak` + `Mutex` | `ProgressManager.swift:351`; `ProgressManager+Properties+Accessors.swift:26`; `ProgressReporter.swift:176` |
| `Subprogress` | API entirely produces/consumes `ProgressManager` | `Subprogress.swift` |
| `Date.FormatStyle.Attributed`, `Date.VerbatimFormatStyle.Attributed`, `Duration.TimeFormatStyle.Attributed`, `Duration.UnitsFormatStyle.Attributed` | `@dynamicMemberLookup` runtime-KeyPath subscripts (also ICU) | `DateFormatStyle.swift:631`; `Date+VerbatimFormatStyle.swift:120`; `Duration+TimeFormatStyle.swift:179`; `Duration+UnitsFormatStyle.swift:551` |
| `PredicateExpressions.KeyPath` | Stores `Swift.KeyPath` value; switches over `PartialKeyPath`/`AnyKeyPath` | `PredicateExpression.swift:153,321` |
| `PredicateCodableConfiguration` (+ `PredicateCodableKeyPathProviding`) | Allowlist of `AnyKeyPath` values (also Codable + reflection) | `PredicateCodableConfiguration.swift:23,82,201` |

### C. Parameter packs / variadic generics

| Type | Reason | Evidence |
|---|---|---|
| `Predicate` | `Predicate<each Input>`, stores `(repeat …Variable<each Input>)` | `Predicate.swift:60,63,70` |
| `Expression` | `Expression<each Input, Output>` | `Expression.swift:14,16,23` |
| `PredicateBindings` | `init<each T>(_ value: repeat …)` | `PredicateBindings.swift:23` |
| `PredicateExpressions.PredicateEvaluate` / `.ExpressionEvaluate` | Store `input: (repeat each Input)` | `PredicateEvaluation.swift:19`; `ExpressionEvaluation.swift:18` |

### D. Casting *to* an existential type / existential metatype

| Type | Reason | Evidence |
|---|---|---|
| `AttributeScope` (protocol) | `unsafeBitCast(…) as? any AttributeScope.Type`, `as? any …AttributedStringKey.Type`; also Codable-config protocols | `AttributeScope.swift:132,227–238` |
| `EncodableAttributedStringKey` / `DecodableAttributedStringKey` / `CodableAttributedStringKey` / `MarkdownDecodableAttributedStringKey` | Defined by `Encoder`/`Decoder` requirements | `AttributedStringCodable.swift:37,52,111` |
| Predicate archiving layer (`Predicate+Codable`, `PredicateExpressionConstruction`, `EncodingContainers+PredicateExpression`) | Codable machinery + `as? any StandardPredicateExpression<Bool>` + variadics | `Predicate+Codable.swift:64`; `PredicateExpressionConstruction.swift:181,231` |

### E. `weak` / `unowned`, non-final generic methods, or OS/Concurrency runtime

| Type | Reason | Evidence |
|---|---|---|
| `FileManager` | `weak` delegate to existential; **non-final generic method on `open` class** (`withFileSystemRepresentation<R>`); existential cast; `Mutex`; syscalls | `SwiftFileManager.swift:250,400`; `FileManager+Files.swift:80` |
| `FileManagerDelegate` | Only usable via the illegal `weak var … : (any FileManagerDelegate)?` | `SwiftFileManager.swift:250` |
| `NotificationCenter` (+ `MainActorMessage`, `AsyncMessage`) | Needs Concurrency runtime: `Task.detached`, `AsyncSequence`, continuations, `@MainActor`, `Mutex` | `NotificationCenter.swift:80`; `ActorQueueManager.swift:76`; `MainActorMessage.swift:112` |
| `NotificationCenter.ObservationToken` | Wraps class with `weak var center` | `NotificationCenterMessage.swift:79` |
| `ProcessInfo` | `Mutex` + env/sysctl/uname/pid syscalls — needs a full OS | `ProcessInfo.swift:38,42` |

### F. ICU dependency (whole module + all localized formatting)

The **entire `FoundationInternationalization` module** is effectively non-portable: every
`*_ICU.swift` / `*+ICU.swift` does `internal import _FoundationICU`, and `ICU/` is pure
C-wrapping plumbing. Concretely non-portable due to ICU:

- **Number:** `IntegerFormatStyle`, `FloatingPointFormatStyle`, `Decimal.FormatStyle`
  (+ `.Percent` / `.Currency` / `.Attributed`), and all `*ParseStrategy`.
- **Date/Duration:** `Date.FormatStyle`, `Date.ParseStrategy`, `Date.VerbatimFormatStyle`,
  `Date.RelativeFormatStyle`, `Date.AnchoredRelativeFormatStyle`, `Date.IntervalFormatStyle`,
  `Duration.TimeFormatStyle`, `Duration.UnitsFormatStyle`.
- **Other:** `ListFormatStyle`, `ByteCountFormatStyle`.
- **Localized capabilities** of `Locale` / `Calendar` / `TimeZone`, and localized `String` comparison.

*(The four `.Attributed` styles above are doubly blocked — runtime KeyPath AND ICU.)*

---

## 2. Cross-cutting blockers (fold into the plan, not per-type)

- **`Mutex` (Synchronization):** used in ~45 files (caches `Locale_Cache`, `Calendar_Cache`,
  `TimeZone_Cache`, `FormatterCache`, `RegexPatternCache`; plus `URL_Impl`, `ProcessInfo`,
  `NotificationCenter`, `ProgressManager`). Only `Atomic` is in embedded today. Implementation
  blocker (swap for a lock/`Atomic` design or await embedded `Mutex`), not a per-type API blocker.
- **Regex engine** availability in embedded is unconfirmed — gates the ISO8601/HTTP/URL styles'
  `RegexComponent` / `CustomConsumingRegexComponent` conformances.
- **Untyped `throws` / `any Error`** — docs contradict; verify on a nightly toolchain.

---

## 3. NOT on the skip list (portable — for contrast)

- **Core value types, after dropping `Codable`/`CustomReflectable`:** `Data`, `Date`,
  `DateInterval`, `UUID`, `Decimal`, `IndexPath`, `DateComponents`, `Calendar` + `RecurrenceRule`,
  `TimeZone`, `Locale`, `URL`, `URLComponents`, `URLQueryItem`, `ComparisonResult`, `SortOrder`.
- **Fully portable already:** the option/enum value-type families (`String.Encoding`,
  `String.CompareOptions`, Calendar/TimeZone/Locale nested components, `Decimal.RoundingMode`,
  `URL.DirectoryHint`/`.Template`, Data option types, `SortComparator`/`ComparableComparator`,
  `Date.FormatStyle.Symbol`, `Date.FormatString`, `ProgressManager.Property`/`Properties`,
  FileManager option/enum types).
- **Fixed-format styles, after dropping the `Codable` protocol requirement:**
  `Date.ISO8601FormatStyle`, `DateComponents.ISO8601FormatStyle`, `Date.HTTPFormatStyle`,
  `DateComponents.HTTPFormatStyle`, `URL.FormatStyle`, `URL.ParseStrategy` (pure Swift, no ICU;
  Regex-conformance caveat applies).
- **Salvageable internal machinery** for a future embedded-native serializer: `BufferView` family,
  `JSONScanner`/`JSON5Scanner`/`JSONMap`/`JSONWriter`, BPlist/XML/OpenStep scanners.

---

## 4. Porting mechanisms

- Gate code with `#if hasFeature(Embedded)` and mark declarations/conformances
  `@_unavailableInEmbedded` (docs explicitly bless this for `Codable` and `Any`).
- Enable the **`EmbeddedRestrictions`** diagnostic group in the normal build to surface
  violations without an embedded toolchain.
- Build with `swiftc -enable-experimental-feature Embedded -wmo` (requires a swift.org nightly
  toolchain — Xcode's does not support Embedded Swift).
