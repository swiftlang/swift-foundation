# swift-foundation Benchmarks

Benchmarks for `swift-foundation` live in this directory as a separate Swift Package. They use the [`package-benchmark`](https://github.com/ordo-one/package-benchmark) plugin.

All commands below must be run from this `Benchmarks/` subdirectory.

---

## Prerequisites

`package-benchmark` uses [`jemalloc`](https://jemalloc.net) for memory allocation statistics. You can either install it or skip it.

`Benchmarks/Package.swift` declares `package-benchmark` with `traits: []`, which disables the `Jemalloc` trait. Benchmarks build and run without jemalloc installed by default.

To opt in to jemalloc and capture malloc metrics, install it first and then pass `--traits Jemalloc`:

- **macOS:** `brew install jemalloc`
- **Linux:** `apt-get install libjemalloc-dev` (Ubuntu/Debian) or equivalent

See the official [Getting Started](https://swiftpackageindex.com/ordo-one/package-benchmark/1.31.0/documentation/benchmark/gettingstarted#Disabling-jemalloc-Swift-61+) article for details.

---

## Running Benchmarks

**Run all benchmarks:**

```
swift package benchmark
```

**Run a specific target:**

```
swift package benchmark --target JSONBenchmarks
swift package benchmark --filter "URL"
```

**List all available benchmarks:**

```
swift package benchmark list
```

**Full help:**

```
swift package benchmark help
```

---

## Choosing Which Foundation to Benchmark Against

The benchmark package supports four configurations, controlled by environment variables. The active configuration is printed at build time.

### Local changes — benchmark your own swift-foundation checkout (default)

By default, with no environment variable set, benchmarks build against the local `swift-foundation` checkout (the parent of this `Benchmarks/` directory). Other package dependencies (e.g. `swift-foundation-icu`) are fetched from their remote URLs. This is the recommended mode for contributors iterating on a performance improvement.

```
swift package benchmark
```

To point at a different local checkout, set `SWIFTCI_USE_LOCAL_DEPS` to the directory *containing* the `swift-foundation` checkout:

```
SWIFTCI_USE_LOCAL_DEPS=/path/to/parent swift package benchmark
```

On Linux, `SWIFTCI_USE_LOCAL_DEPS` resolves to `swift-corelibs-foundation` instead.

> **Note:** `SWIFTCI_USE_LOCAL_DEPS` is also set by the Swift repo CI when running full toolchain unit tests, so that *all* dependencies (including transitive ones like `swift-foundation-icu`) resolve to locally checked-out copies rather than fetching from git.

### GitHub main branch — compare against the latest published commit

```
USE_PACKAGE=1 swift package benchmark
```

Fetches and benchmarks against the `main` branch of `swift-foundation` (or `swift-corelibs-foundation` on Linux) from GitHub. Useful for comparing a local build against a known top-of-tree commit.

### System Foundation / toolchain

```
USE_TOOLCHAIN=1 swift package benchmark
```

On macOS this uses `Foundation.framework`. On Linux it uses the Foundation from the installed Swift toolchain. Use this only if you specifically want to measure the system-installed version.   
