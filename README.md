# Swift Foundation

The Foundation framework defines a low-level layer of functionality that is useful for almost all applications. It is designed with these goals in mind:

* Provide a small set of basic utility types.
* Make software development easier by introducing consistent conventions that can be widely adopted by the Swift ecosystem.
* Support internationalization and localization, to make software accessible to users around the world.
* Provide a level of OS independence, to enhance portability.

This project is a preview of a unified Swift implementation of Foundation for all platforms. While the new package is not yet complete, it provides the first building blocks for early testing and contributions.

## Implementation Progress

The following types are available in the preview package, with more to come later:

* FoundationEssentials
    * `AttributedString`
    * `Data`
    * `Date`
    * `DateInterval`
    * `JSONEncoder`
    * `JSONDecoder`
    * `Predicate`
    * `String` extensions
    * `UUID`
* Internationalization
    * `Calendar`
    * `TimeZone`
    * `Locale`
    * `DateComponents`
    * `FormatStyle`
    * `ParseStrategy`


Wherever possible, code is shared between all platforms. In cases where platform-specific code is needed within a single source file, a compiler directive is used to include or exclude it.

For internationalization support on non-Darwin platforms, we created a separate package named *[FoundationICU](https://github.com/apple/swift-foundation-icu)*. This repository contains the necessary ICU implementations and data from the upstream [Apple OSS Distribution ICU](https://github.com/apple-oss-distributions/ICU), wrapped in Swift so FoundationInternationalization can easily depend on it. Using a common version of ICU will result in more reliable and consistent results when formatting dates, times, numbers, and more. As the upstream Apple ICU updates to newer version of ICU, the FoundationICU package will be updated with those changes.

> Note: The Foundation Preview package depends on the under-development [Swift 5.9 toolchain](https://www.swift.org/download).

## Performance

Being written in Swift, this new implementation provides some major benefits over the previous C and Objective-C versions. Code is shared across all platforms, is much easier to read and write, and also provides some great performance improvements. 

`Locale`, `TimeZone` and `Calendar` no longer require bridging from Objective-C. Common tasks like getting a fixed `Locale` are an order of magnitude faster for Swift clients. `Calendar`'s ability to calculate important dates can take better advantage of Swift’s value semantics to avoid intermediate allocations, resulting in over a 20% improvement in some benchmarks. Date formatting using `FormatStyle` also has some major performance upgrades, showing a massive 150% improvement in a benchmark of formatting with a standard date and time template.

Even more exciting are the improvements to JSON decoding in the new package. Foundation has a brand-new Swift implementation for `JSONDecoder` and `JSONEncoder`, eliminating costly roundtrips to and from the Objective-C collection types. The tight integration of parsing JSON in Swift for initializing `Codable` types improves performance, too. In benchmarks parsing [test data](https://www.boost.org/doc/libs/master/libs/json/doc/html/json/benchmarks.html), there are improvements in decode time from 200% to almost 500%.

## Governance

The success of the Swift language is a great example of what is possible when a community comes together with a shared interest.

For Foundation, our goal is to create the best fundamental data types and internationalization features, and make them available to Swift developers everywhere. It will take advantage of emerging features in the language as they are added, and enable library and app authors to build higher level API with confidence.

Moving Foundation into this future requires not only an improved implementation, but also an improved process for using it outside of Apple’s platforms. Therefore, Foundation now has a path for the community to add new API for the benefit of Swift developers on every platform.

Swift Foundation is an independent package project in its early incubation stages. Inspired by the workgroups in the Swift project, it has a workgroup to (a) oversee [community API proposals](/Users/tony/Desktop/FoundationPreview_Final.md) and (b) to closely coordinate with developments in the Swift project and those on Apple’s platforms. In the future, we will explore how to sunset the existing [swift-corelibs-foundation](https://github.com/apple/swift-corelibs-foundation) and migrate to using the new version of Foundation created by this project.

The workgroup meets regularly to review proposals, look at emerging trends in the Swift on Server ecosystem, and discuss how the library can evolve to best meet our common goals.
## Next Steps

Quality and performance are our two most important goals for the project. Therefore, the plans for the first half of 2023 are continuing refinement of the core API, adding to our suites of unit and performance tests, and expanding to other platforms where possible,  using the most relevant code from [swift-corelibs-foundation](https://github.com/apple/swift-corelibs-foundation).

We also want to try out our new community API proposal process. We aim to accept around three small proposals with corresponding Swift implementations. Experience from running reviews and accepting new API will help to refine the process, and allow scaling up to more contributions later this year and beyond.

Later this year, the porting effort will continue. It will bring high quality Swift implementations of additional important Foundation API such as `URL`, `Bundle`, `FileManager`, `FileHandle`, `Process`, `SortDescriptor`, `SortComparator` and more. 
## Contributions

Foundation welcomes contributions from the community that align with our goals for the project. The package uses [GitHub Issues](https://github.com/apple/swift-corelibs-foundation) for tracking bugs, feature requests, and other work. Please see the [CONTRIBUTING](https://github.com/apple/swift-foundation/blob/main/CONTRIBUTING.md) document for more information, including the process for accepting community contributions for new API in Foundation.
