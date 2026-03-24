# Obtaining Foundation

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2026 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

There are multiple ways to obtain Foundation, and they have different tradeoffs
to consider. This document discusses the various ways Foundation is distributed
and offers recommended workflows.

_This document was inspired by the equivalent [Distributions.md](https://github.com/swiftlang/swift-testing/blob/main/Distributions.md) in [swift-testing](https://github.com/swiftlang/swift-testing)._

## Distribution locations

Foundation is distributed in the following places:

* In Apple's [macOS, iOS, and other Apple platforms][apple-platforms], as a
  framework built into the operating system.
* In [Swift.org toolchains][install], versions 6.0 and later (for
  [supported platforms][]), as a library included in the toolchain.

The locations above are considered **built-in** because they're included with a
larger collection of software (such as an operating system, toolchain, or IDE)
and consist of _pre-compiled_ copies of the `FoundationEssentials` and
`FoundationInternationalization` modules.

> [!IMPORTANT]
> Prefer using a built-in copy of Foundation unless you're making changes to
> Foundation itself.

Foundation is also available as a Swift **package library product** from the
[swiftlang/swift-foundation][swift-foundation] repository. This copy is _not_
considered built-in because it must be downloaded and compiled separately by
each client.

## Caveats when using swift-foundation as a package

Although Foundation is available as a Swift package and you _can_ declare a
dependency on [swift-foundation][] during development, it is not suitable for
use in a package or app that you intend to ship. Doing so has several
downsides:

* **It requires building Foundation and its dependencies from source.** This significantly increases
  your build time.
* **It may encounter build failures when another package uses a built-in
  Foundation.** If you use swift-foundation as a package, but you depend on a
  library from another package which uses a built-in copy of Foundation (as
  this document recommends), this can cause build failures due to duplicate
  symbol definitions or module conflicts.

## When to use swift-foundation as a package

If you are contributing to Foundation or otherwise working on its source code,
building it as a Swift package is the recommended workflow. The core contributors
regularly develop Foundation this way, and its CI builds as a package as well.
See [Contributing][] for detailed steps on getting started.

It's also sometimes helpful to use swift-foundation as a package in order to
validate how changes made to Foundation will impact tools or libraries that
depend on it, or to test changes to both Foundation and a related project in
conjunction with each other. When using one of these workflows locally, it's
important to be mindful of the [caveats][] above, but during local development
it's often possible to take extra care and control things sufficiently to avoid
those problems.

[apple-platforms]: https://developer.apple.com/documentation/foundation
[install]: https://www.swift.org/install
[supported platforms]: https://github.com/swiftlang/swift-foundation/blob/main/README.md
[Xcode IDE]: https://developer.apple.com/xcode/
[Command Line Tools for Xcode package]: https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/
[swift-foundation]: https://github.com/swiftlang/swift-foundation
[swift-collections]: https://github.com/swiftlang/swift-collections
[swift-foundation-icu]: https://github.com/swiftlang/swift-foundation-icu
[swift-syntax]: https://github.com/swiftlang/swift-syntax
[Contributing]: https://github.com/swiftlang/swift-foundation/blob/main/CONTRIBUTING.md
[caveats]: #caveats-when-using-swift-foundation-as-a-package
