# swift-foundation Contribution Guidelines

---

## Code Style

**Do not manually wrap comments or DocC.** Keep it on one line unless splitting genuinely improves readability.

**Add a comment when the *why* is non-obvious:** non-obvious assumptions, platform workarounds, deliberately unusual choices (e.g. two enum raw values with the same raw value on purpose).

**Do not add comments that:**
- Merely explain what the implementation does
- Reference the PR or bug that motivated the change (belongs in the PR description)
- Repeat information accessible from `git blame`

**Using TODOs:** Remove stale TODOs when addressing them. For future refactoring opportunities you are *not* addressing in this PR, use `// TODO:`.

**When you reimplement functionality that belongs in the standard library** (e.g. Unicode scalar property queries), add a `// TODO:` referencing a filed enhancement request number so the local workaround can be removed once the stdlib gains the capability.

**DocC must be accurate.** Do not mention parameters in documentation that do not affect the described behavior.

**Do not leave a brace, keyword, or condition orphaned on its own line** when it can be joined with the adjacent line without hurting readability.

**Avoid abbreviations** Prefer full descriptive names. If a domain term has a conventional abbreviation, name the public parameter in full and reserve the abbreviation for internal use only.

**Avoid C-style prefixes on constant names** (e.g. `_kMyConstant`). Use descriptive names instead.

**Keep type names and file names in sync.** If a file defines a single primary type, name the file after that type.

**Use the `if let` shorthand when unwrapping to a non-optional.** When the only purpose is to bind a non-`nil` optional to a non-optional of the same name, write `if let value` rather than `if let value = value`. This applies to each binding in a comma-separated condition list too.

---

## Code Structure

**Factor out shared constants and logic.** If two or more implementations share constants or logic, extract them.

**Consolidate near-duplicate logic.** If two functions do almost the same thing, or one check is always immediately followed by another that repeats it, merge them into a single implementation.

**Decompose complex features into smaller, focused PRs.**

**Move struct-building logic into the type's own initializer.** If a block of code exists only to populate the fields of a type before constructing it, make it an `init` on that type instead of leaving it as free-floating setup code at the call site.

**Prefer enums or named constants over bare integer or "magic" values.** A parameter that selects among a fixed set of options reads far better as an enum (or at least a symbolic constant) than as a raw `Int`, both at call sites and in the `switch` statements that consume it.

**Keep a type focused on a single responsibility.** A type that loads resource data should stay focused on loading; move unrelated concerns (for example, condition or predicate helpers) into their own type rather than accreting them onto it.

**Do not introduce a stored property or local used exactly once.** If a value is computed and then consumed in a single place, inline the expression at its use site rather than naming it.

**Respect encapsulation.** Avoid reaching into another type's internal representation to take a shortcut. When a performance path genuinely requires it, add a `// TODO:` (and file an issue) to revisit the design later.

---

## API Design

**A function's `nil` return should have one unambiguous meaning.** Do not overload `nil` to mean both "not applicable here" and "no result found."

**Do not provide a default protocol-witness implementation when existing conformances already diverge in real behavior.** There is no single "standard" behavior to default to, and a default makes divergence easy to overlook. Require each conformance to implement it explicitly.

---

## Coding Best Practices

**Avoid force unwrap (`!`) and force cast (`as!`).** Force unwrap crashes the process on failure with no useful diagnostic. Use:
- `guard let` / `if let` for optional unwrapping
- `try`/`#expect` in tests
- `as?` with appropriate handling for casting
- `precondition` / `preconditionFailure` / `fatalError` when a nil or wrong type represents a programmer error

**Avoid unsafe APIs** (`UnsafeMutablePointer`, `UnsafeRawPointer`, `UnsafeBufferPointer`, etc.) unless there is no safe alternative. When unsafe is required, isolate it to a small, focused helper.

**`@unchecked Sendable`, `nonisolated(unsafe)`**: Prefer plain `Sendable`; only reach for `@unchecked Sendable` when the compiler genuinely cannot prove conformance. If you need to use these, add:
- a code or PR comment explaining why the suppression is safe
- `// TODO:` with a migration path to remove the annotation if applicable

**Prefer `Mutex` for synchronizing shared mutable state** over ad-hoc caching or locking helpers introduced before `Mutex` was available.

**Avoid constructing expensive value types repeatedly inside nested loops.** Restructure to build shared state once and only vary what actually changes across iterations.

**Avoid `KeyPath` for performance-critical property access.** It involves runtime dispatch. Profile against direct property accessors before choosing `KeyPath` in a hot path.

**Check for overflow in multiplications used for size or capacity calculations** (e.g. with `multipliedReportingOverflow`) and bail out rather than letting it silently wrap or trap.

**Avoid capturing outer-scope variables in helper functions or closures.** Pass them as explicit parameters so the dependency is traceable at the call site.

**Build strings by appending into a caller-supplied buffer** rather than returning and re-allocating an intermediate string for each step. Pass an `inout String`, or use `Span` / `OutputBuffer`, so a multi-part result is assembled in one buffer. See `URL_Impl.swift` for an example.

**Avoid dropping to `unicodeScalars`.** When the significant characters are ASCII, prefer the UTF-8 domain (`string.utf8`, `string.withUTF8 { }`, `utf8Span`) and add an all-ASCII fast path via `utf8Span.isKnownASCII`. Where performance is not the concern, prefer readable String-level APIs (`starts(with:)`, `lowercased()`) over a hand-rolled scalar loop.

**Prefer `withTemporaryAllocation` for short-lived scratch buffers** over manual unsafe allocation, once the `swift-tools-version` supports it.

**Do not apply `@inline(__always)` reflexively.** It increases code size. Confirm a measured improvement before adding it, rather than sprinkling it across a file.

**Prefer idiomatic stdlib conveniences over manual multi-step equivalents.** For example, `String(contentsOf:)` instead of reading `Data` and decoding it separately, or a small `TextOutputStream` writing to stderr with `print(_:to:)` instead of `FileHandle.standardError` plus `.data(using: .utf8)`.

---

## Testing

**Do not force unwrap in tests.** Use `try`/`#require`. A crash aborts the entire suite rather than reporting a failure.

**Do not `print` in tests.** `print` output is buried in CI logs. Use assertions or remove them.

**Tests must be relevant to the code path changed.** Add a test that fails before the fix and passes after. Additional tests are welcome as long as they exercise the changed behavior.

**Use `swift-benchmark` to measure performance.** Add benchmark entries under [`Benchmarks/`](https://github.com/swiftlang/swift-foundation/tree/main/Benchmarks). Keep setup code outside the measured scope, or use explicit start/stop measuring functions.

**Parameterize test probes.** Pass test inputs as arguments rather than hardcoding them. See [parameterized testing](https://developer.apple.com/documentation/testing/parameterizedtesting) for the Swift Testing API.

**Add exit tests when adding preconditions.** If you add a `precondition`, `preconditionFailure`, or `fatalError` to enforce a programmer contract, use `#expect(processExitsWith:)` to verify that the process terminates under the invalid input. Read more about [exit testing here](https://developer.apple.com/documentation/testing/exit-testing).

---

## Platform Flags

**Tests and implementation should work on all supported platforms by default.** Reach for `#if os(...)` only when the behavior genuinely differs or the API does not exist on that platform.

**Add comments for platform conditionals to explain the divergence.** If a platform (e.g. OpenBSD) partially implements an API category, do not lump it under a broad flag like `NO_LOCALIZATION`. Use an explicit `|| os(OpenBSD)` with a comment.

**Plan the removal of temporary build flags.** When a flag gates a replacement for an existing implementation (e.g. a native Swift path superseding an ICU one), decide up front how and when the flag and the superseded code get retired, rather than leaving both to coexist indefinitely.

