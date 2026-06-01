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

**Factor out shared constants and logic.** If two implementations share constants or logic, extract them.

**Decompose complex features into smaller, focused PRs.** Reviewers will start CI early and offer to take items as follow-ups.

---

## Coding Best Practices

**Avoid force unwrap (`!`) and force cast (`as!`).** Force unwrap crashes the process on failure with no useful diagnostic. Use:
- `guard let` / `if let` for optional unwrapping
- `try`/`XCTUnwrap` in tests
- `as?` with appropriate handling for casting
- `precondition` / `preconditionFailure` / `fatalError` when a nil or wrong type represents a programmer error

**Avoid unsafe APIs** (`UnsafeMutablePointer`, `UnsafeRawPointer`, `UnsafeBufferPointer`, etc.) unless there is no safe alternative. When unsafe is required, isolate it to a small, focused helper.

**`@preconcurrency`, `@unchecked Sendable`, `nonisolated(unsafe)`** each require:
- A comment explaining why the suppression is safe
- A `// TODO:` with a migration path to remove the annotation if applicable

---

## Testing

**No force unwrap in tests.** Use `try`/`XCTUnwrap`. A crash aborts the entire suite rather than reporting a clean failure.

**No `print` in tests.** `print` output is buried in CI logs. Use assertions.

**Write behavioral tests, not just happy-path tests.** If your implementation exits early or skips work under certain conditions, add a test that proves the skipped work did not happen — not just that the return value is correct.

**Tests must be relevant to the code path changed.** A good test fails before the fix and passes after. Additional tests are welcome as long as they exercise the changed behavior.

**Use `swift-benchmark` to measure performance.** Add benchmark entries under [`Benchmarks/`](https://github.com/swiftlang/swift-foundation/tree/main/Benchmarks). Keep setup code outside the measured scope, or use explicit start/stop measuring.

**Parameterize test probes.** Pass test inputs as arguments rather than hardcoding them. See [parameterized testing](https://developer.apple.com/documentation/testing/parameterizedtesting) for the Swift Testing API.

---

## Platform Flags

**Tests and implementation should work on all supported platforms by default.** Reach for `#if os(...)` only when the behavior genuinely differs or the API does not exist on that platform.

**Platform carve-outs need comments explaining the divergence.** If a platform (e.g. OpenBSD) partially implements an API category, do not lump it under a broad flag like `NO_LOCALIZATION`. Use an explicit `|| os(OpenBSD)` with a comment.

