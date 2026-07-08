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

**DocC must be accurate.** Do not mention parameters in documentation that do not affect the described behavior.

**Do not leave a brace, keyword, or condition orphaned on its own line** when it can be joined with the adjacent line without hurting readability.

**Avoid abbreviations** Prefer full descriptive names. If a domain term has a conventional abbreviation, name the public parameter in full and reserve the abbreviation for internal use only.

**Avoid C-style prefixes on constant names** (e.g. `_kMyConstant`). Use descriptive names instead.

---

## Code Structure

**Factor out shared constants and logic.** If two or more implementations share constants or logic, extract them.

**Consolidate near-duplicate logic.** If two functions do almost the same thing, or one check is always immediately followed by another that repeats it, merge them into a single implementation.

**Decompose complex features into smaller, focused PRs.**

**Move struct-building logic into the type's own initializer.** If a block of code exists only to populate the fields of a type before constructing it, make it an `init` on that type instead of leaving it as free-floating setup code at the call site.

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

**`@unchecked Sendable`, `nonisolated(unsafe)`**: If you need to use these, add:
- a code or PR comment explaining why the suppression is safe
- `// TODO:` with a migration path to remove the annotation if applicable

**Avoid constructing expensive value types repeatedly inside nested loops.** Restructure to build shared state once and only vary what actually changes across iterations.

**Avoid `KeyPath` for performance-critical property access.** It involves runtime dispatch. Profile against direct property accessors before choosing `KeyPath` in a hot path.

**Check for overflow in multiplications used for size or capacity calculations** (e.g. with `multipliedReportingOverflow`) and bail out rather than letting it silently wrap or trap.

**Avoid capturing outer-scope variables in helper functions or closures.** Pass them as explicit parameters so the dependency is traceable at the call site.

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

