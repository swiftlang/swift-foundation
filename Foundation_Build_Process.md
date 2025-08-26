# Foundation Build Process

This document outlines how Foundation (swift-corelibs-foundation, swift-foundation, and swift-foundation-icu) is built in various scenarios. Foundation is built in a variety of different ways between at desk, in testing CI, and in full toolchain builds. Each build variant serves a purpose outlined below but may have subtle behavioral differences compared to other variants.

For the purpose of this document, an "Individual Build" indicates a build of just a particular repo (and any repo within the realm of Foundation/our packages that it depends on). This is different from a toolchain build which must always build the entire toolchain (the compilers, the standard library, all of Foundation, and other projects like dispatch/swiftpm/etc.).

## Getting Started

If you're looking to quickly get a build of Foundation locally to test a change, the fastest way is to build via SwiftPM. To do so, follow these steps:

**Via the Command Line (all platforms):** run `swift test` to build the project and run all unit tests, or `swift build` to just build the project without running tests

**Via Xcode (Apple platforms only):** Open the `Package.swift` file in Xcode and click *Product > Test* to build the project and run all unit tests, or *Product > Build* to just build the project without running tests

This is the quickest way to iterate on Foundation to add new APIs or fix bugs. SwiftPM's command line interface and IDE integrations provide a variety of options to run specific tests or run tests in parallel to achieve results faster. Check out the detailed sections below for more information about the SwiftPM build or the other build variants for Foundation.

## Individual Build (via SwiftPM)

Each individual project can be built via SwiftPM. This is useful when quickly iterating at desk and when developing within IDEs with integrated SwiftPM support such as Xcode. The SwiftPM build is configured via the `Package.swift` manifest at the root directory of each project. This build format supports building only Foundation components and their immediate dependencies without the need to build other toolchain libraries such as the standard library or the compiler itself. This is also the only build format that supports building and running unit tests.

### When is this configuration used?

- At desk when building via SwiftPM
- In CI when running unit tests for pull requests

### How can I invoke a build via this configuration?

SwiftPM builds can be invoked via an IDE integration (such as building within Xcode), or by using the `swift build` and `swift test` command line tools.

_Note: Subsequent SwiftPM builds will not automatically update to newer commits of downstream Foundation projects like swift-foundation-icu. If you encounter build failures after checking out a new branch or pulling from the remote repo, you can run `swift package update` to update your local dependency checkouts to match top-of-tree to ensure you have the required versions of dependencies._

### How are dependencies fetched?

Dependencies are fetched via the SwiftPM dependency system. The required dependencies are specified in the `Package.swift` manifest and will be checked out and built automatically via SwiftPM.

### Project Specific Notes

- FoundationMacros
	- SwiftPM builds the `FoundationMacros` project as an executable. The compiler automatically uses this executable to communicate with the macro plugin. This is different than the CMake builds which will build the macro as a library instead, but the plugin itself has the same behavior.
- swift-foundation-icu
	- Due to an Xcode bug, defined conditions specified in the `Package.swift` manifest may not be appropriately provided to the clang invocations when building C/CXX files via SwiftPM's Xcode integration. Therefore, when building swift-foundation-icu (or projects that depend on it) in Xcode, it may build with different behaviors (ex. the ICU library will depend on the system ICU data files rather than the data files within the swift-foundation-icu repo). This behavioral difference does not apply when building from the command line (ex. `swift build`/`swift test`)
- swift-collections
	- When building against the swift-collections library via SwiftPM, the various collection APIs are provided via a set of modules (ex. `OrderedCollections`). This is different from the CMake and `FOUNDATION_FRAMEWORK` builds which build swift-collections into a single module.
- swift-corelibs-foundation
	- The SCL-F project is only able to be built on non-Darwin platforms. The SwiftPM manifest lists the required macOS deployment target as "macOS 99" to indicate this. All other projects can be built via SwiftPM on any platform.

## Individual Build (via CMake)

Each individual project can also be built via CMake. This is useful when making and validating changes to the CMake files at desk (for example, when adding/removing files or changing dependencies and build settings). This build is very similar to the CMake build that the swift toolchain uses, but does not require building all toolchain components such as the compiler or the standard library, resulting in substantially quicker build times. This build is configured via the `CMakeLists.txt` files present throughout each repository.

### When is this configuration used?

- At desk when building via CMake
- In CI when building pull requests (to validate that the CMake build is not broken by a change)

### How can I invoke a build via this configuration?

_Note: Building via CMake requires that Ninja and CMake (v3.24 or greater) are both pre-installed_

1. Ensure external dependencies such as dispatch, curl, libxml, etc. are built _(swift-corelibs-foundation only)_
2. Configure and generate the cmake build via `cmake -B<build folder> -G Ninja -DCMAKE_INSTALL_PREFIX=<install folder>`
	- Add `-Ddispatch_DIR=<dispatch build folder>/cmake/modules` etc. for each external dependency _(swift-corelibs-foundation only)_
3. Build the project via `cmake --build <build folder>`
4. Install the project into the `<install folder>` via `cmake --build <build folder> --target install`

### How are dependencies fetched?

Dependencies will be fetched via CMake's `FetchContent` feature. The required dependencies are specified within the `CMakeLists.txt` files within the repo and are automatically checked out by CMake. If you'd like to build against a local copy of the sources for a dependency, you can provide its path via an argument to the command line invocation of CMake:

- `-D_SwiftFoundationICU_SourceDIR=<path to swift-foundation-icu>` provides a path to a local copy of swift-foundation-icu sources
- `-D_SwiftCollections_SourceDIR=<path to swift-collections>` provides a path to a local copy of swift-collections sources
- `-D_SwiftFoundation_SourceDIR=<path to swift-foundation>` provides a path to a local copy of swift-foundation sources
- `-DSwiftSyntax_DIR=<path to swift-syntax build folder>/cmake/modules` provides a path to a local copy of swift-syntax
	- _Note: this SwiftSyntax project must be already built by CMake and the directory must be a path to the produced `cmake/modules` folder_

### Project Specific Notes

- FoundationMacros
	- CMake builds the `FoundationMacros` project as a shared library. The compiler can load this shared library to call the macro plugin, but it will not find this shared library automatically when building CMake dependents. Any downstream CMake target that wishes to use Foundation macros needs to add the `-plugin-path` compiler flag pointing to the location of the built macro library. The `FoundationEssentials` target currently has this setting applied.
- swift-collections
	- In CMake builds, the swift-collections package is built into a single `_FoundationCollections` module (including contents of the unstable `_RopeModule`) rather than separated modules like the SwiftPM build.
	- Due to Windows limitations, this `_FoundationCollections` module _only_ contains the `OrderedCollections` and `_RopeModule` APIs

## Toolchain Build

The toolchain build involves building every component within the swift toolchain (LLVM, the swift compiler, standard library, Foundation, XCTest, LLBuild, SwiftPM, etc.).

### When is this configuration used?

- In CI on the Swift repo when requesting a full toolchain build via `@swift-ci please build toolchain`
- Nightly when producing the nightly toolchain of a particular branch


### How can I invoke a build via this configuration?

On Linux, this can be accomplished using the following command from within the [Swift repo](https://github.com/apple/swift):

```shell
utils/build-script --preset buildbot_linux,no_test install_destdir=<path to some installation folder> installable_package=<path to some .tar.gz file>
```

The above command will build a toolchain installing each piece into `install_destdir` and then package that directory up into a `.tar.gz` file at `installable_package`. This is what is invoked to build the Swift toolchain that we produce nightly.

### How are dependencies fetched?

Dependencies are managed by the `utils/update-checkout` script. This will check out all necessary dependencies and place them in directories alongside your `swift` checkout. When the build script runs, it will provide the paths to swift-foundation, swift-foundation-icu, swift-collections, and swift-syntax to the swift-corelibs-foundation build when invoking CMake.

### Project Specific Notes

- General Notes
	- Once Foundation is built, the build script will build XCTest and LLBuild before installing Foundation. The XCTest and LLBuild CMake invocations are provided with `Foundation_DIR` and they will build against the provided cmake modules. Once these projects are built, the build script will install Foundation. From that point onwards, all downstream projects will pick up Foundation from the installed toolchain path rather than via the CMake exports.
- FoundationMacros
	- Since the macro dylib is not installed until after XCTest and LLBuild are built, if either project or any other target before Foundation's install happens wishes to use Foundation's macros, they need to explicitly specify a `-plugin-path` pointing to the Foundation macro library.
- `_FoundationICU`/`_FoundationCollections`/`_FoundationCShims`/`CoreFoundation`
	- Since we do not enable library evolution when building the Foundation targets, all modules (even those imported with `internal`) need to be present in the toolchain for downstream clients to build successfully. These modules are installed, but are not accessible to use via clients. The implementations are statically linked into `Foundation`/`FoundationEssentials`/`FoundationInternationalization` so their binary contents cannot be used directly by clients. Additionally, the `_FoundationCollections` swift module is explicitly built with an allowlist containing only the `FoundationEssentials` module.
- `_FoundationICU`/`_FoundationCShims`
	- The Windows installer scripts must maintain an explicit list of every header file included within these C modules. This list is not derived from the package manifest or the CMake files, but is instead listed in the [swift-installer-scripts](https://github.com/swiftlang/swift-installer-scripts) repo. When adding/removing header files from these modules, take care to update the installer script in sync with this change.

## `FOUNDATION_FRAMEWORK` Build

The swift-foundation project is also built internally within Apple as part of the `Foundation.framework` library that is installed into the OS of all Apple platforms. This is a special build configuration with the `FOUNDATION_FRAMEWORK` condition defined that is not built via open source CI. Code within this condition is only relevant when building swift-foundation as part of `Foundation.framework` and is not used in any open source builds of Swift. Note that this does not apply to swift-foundation-icu (which is built differently internally) or swift-corelibs-foundation (which is not built for Darwin platforms).

## Benchmarks

Benchmarks for `swift-foundation` are in a separate Swift Package in the `Benchmarks` subfolder of this repository. 
They use the [`package-benchmark`](https://github.com/ordo-one/package-benchmark) plugin.
Benchmarks depends on the [`jemalloc`](https://jemalloc.net) memory allocation library, which is used by `package-benchmark` to capture memory allocation statistics.
An installation guide can be found in the [Getting Started article](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark/gettingstarted#Installing-Prerequisites-and-Platform-Support) of `package-benchmark`. 
Afterwards you can run the benchmarks from CLI by going to the `Benchmarks` subfolder (e.g. `cd Benchmarks`) and invoking:
```
swift package benchmark
```
