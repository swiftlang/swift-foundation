# swift-foundation Contribution Guidelines

---

## Code Style

**Do not manually wrap comments or DocC.**

**Add a comment when the *why* is non-obvious:** non-obvious assumptions, platform workarounds, deliberately unusual choices (e.g. two enum raw values with the same raw value on purpose).

**Do not add comments that:**
- Merely explain what the implementation does
- Reference the PR or bug that motivated the change (belongs in the PR description)
- Repeat information accessible from `git blame`

**Using TODOs:** Remove stale TODOs when addressing them. For future refactoring opportunities you are *not* addressing in this PR, use `// TODO:`.

**DocC must be accurate.** Do not mention parameters in documentation that do not affect the described behavior.

---

## Code Structure

**Factor out shared constants and logic.** If two or more implementations share constants or logic, extract them.

**Decompose complex features into smaller, focused PRs.**

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

