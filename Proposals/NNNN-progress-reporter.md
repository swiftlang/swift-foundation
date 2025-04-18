# `ProgressReporter`: Progress Reporting in Swift Concurrency  

* Proposal: SF-NNNN
* Author(s): [Chloe Yeo](https://github.com/chloe-yeo)
* Review Manager: TBD
* Status: **Pitch**

## Revision history

* **v1** Initial version
* **v2** Major Updates: 
    - Replaced generics with `@dynamicMemberLookup` to account for additional metadata
    - Replaced localized description methods with `ProgressReporter.FormatStyle` and `ProgressReporter.FileFormatStyle`
    - Replaced top level `totalCount` to be get-only and only settable via `withProperties` closure
    - Added the ability for `completedCount` to be settable via `withProperties` closure
    - Omitted checking of `Task.cancellation` in `complete(count:)` method
* **v3** Major Updates: 
    - Renamed `ProgressReporter.Progress` struct to `Subprogress` 
    - Renamed `assign(count:)` method to `subprogress(assigningCount:)` 
    - Restructure examples in `Proposed Solution` to showcase clearer difference of progress-reporting framework code and progress-observing developer code  

## Table of Contents 

* [Introduction](#introduction)
* [Motivation](#motivation)
* [Proposed Solution and Example](#proposed-solution-and-example)
    * [Reporting Progress (General Operations)](#reporting-progress-general-operations)
    * [Reporting Progress (File-Related Operations)](#reporting-progress-file\-related-operations)
    * [Advantages of using `Subprogress` as Currency Type](#advantages-of-using-subprogress-as-currency-type)
    * [Interoperability with Existing `Progress`](#interoperability-with-existing-progress)
* [Detailed Design](#detailed-design)
    * [`ProgressReporter`](#progressreporter)
    * [`ProgressReporter.Properties`](#progressreporterproperties)
    * [`Subprogress`](#subprogress)
    * [`ProgressReporter.FormatStyle`](#progressreporterformatstyle)
    * [`ProgressReporter.FileFormatStyle`](#progressreporterfileformatstyle)
    * [Interoperability with Existing `Progress`](#methods-for-interoperability-with-existing-progress)
        * [`ProgressReporter` \(Parent\) \- `Progress` \(Child\)](#progressreporter-parent---progress-child)
        * [`Progress` \(Parent\) \- `ProgressReporter` \(Child\)](#progress-parent---progressreporter-child)
* [Impact on Existing Code](#impact-on-existing-code)
* [Future Directions](#future-directions)
    * [ProgressView Overloads](#progressview-overloads)
    * [Distributed ProgressReporter](#distributed-progressreporter)
    * [Enhanced `FormatStyle`](#enhanced-formatstyle)
* [Alternatives Considered](#alternatives-considered)
    * [Alternative Names](#alternative-names)
    * [Introduce `ProgressReporter` to Swift standard library](#introduce-progressreporter-to-swift-standard-library)
    * [Implement `ProgressReporter` as a Generic Class](#implement-progressreporter-as-a-generic-class)
    * [Implement `ProgressReporter` as an Actor](#implement-progressreporter-as-an-actor)
    * [Implement `ProgressReporter` as a Protocol](#implement-progressreporter-as-a-protocol)
    * [Introduce an `Observable` Adapter for `ProgressReporter`](#introduce-an-observable-adapter-for-progressreporter)
    * [Introduce Method to Generate Localized Description](#introduce-method-to-generate-localized-description)
    * [Introduce Explicit Support for Cancellation, Pausing, Resuming of `ProgressReporter`](#introduce-explicit-support-for-cancellation-pausing-and-resuming-of-progressreporter)
    * [Check Task Cancellation within `complete(count:)` Method](#check-task-cancellation-within-completecount-method)
    * [Introduce totalCount and completedCount Properties as UInt64](#introduce-totalcount-and-completedcount-properties-as-uint64)
    * [Store Existing `Progress` in TaskLocal Storage](#store-existing-progress-in-tasklocal-storage)
    * [Add Convenience Method to Existing `Progress` for Easier Instantiation of Child Progress](#add-convenience-method-to-existing-progress-for-easier-instantiation-of-child-progress)
    * [Allow for Assignment of `ProgressReporter` to Multiple Progress Reporter Trees](#allow-for-assignment-of-progressreporter-to-multiple-progress-reporter-trees)
    * [Replace Count\-based Relationships between `ProgressReporter`](#replace-countbased-relationships-between-progressreporter)
    * [Introduce Additional Convenience for Getting `Subprogress`](#introduce-additional-convenience-for-getting-subprogress)
* [Acknowledgements](#acknowledgements)

## Introduction

Progress reporting is a generally useful concept, and can be helpful in all kinds of applications: from high level UIs, to simple command line tools, and more.

Foundation offers a progress reporting mechanism that has been very popular with application developers on Apple platforms. The existing `Progress` class provides a self-contained, tree-based mechanism for progress reporting and is adopted in various APIs which are able to report progress. The functionality of the `Progress` class is two-fold –– it reports progress at the code level, and at the same time, displays progress at the User Interface level. While the recommended usage pattern of `Progress` works well with Cocoa's completion-handler-based async APIs, it does not fit well with Swift's concurrency support via async/await.

This proposal aims to introduce an efficient, easy-to-use, less error-prone Progress Reporting API —— `ProgressReporter` —— that is compatible with async/await style concurrency to Foundation. To further support the use of this Progress Reporting API with high-level UIs, this API is also `Observable`. 

## Motivation

A progress reporting mechanism that is compatible with Swift's async/await style concurrency would be to pass a `Progress` instance as a parameter to functions or methods that report progress. The current recommended usage pattern of the existing `Progress`, as outlined in [Apple Developer Documentation](https://developer.apple.com/documentation/foundation/progress), does not fit well with async/await style concurrency. Typically, a function that aims to report progress to its callers will first return an instance of the existing `Progress`. The returned instance is then added as a child to a parent `Progress` instance. 

In the following example, the function `chopFruits(completionHandler:)` reports progress to its caller, `makeSalad()`.  

```swift
public func makeSalad() {
    let progress = Progress(totalUnitCount: 3) // parent Progress instance 
    let subprogress = chopFruits { result in // child Progress instance 
        switch result {
            case .success(let progress): 
                progress.completedUnitCount += 1
            case .failure(let error): 
                print("Fruits not chopped")
        }
    } 
    progress.addChild(subprogress, withPendingUnitCount: 1) 
}

public func chopFruits(completionHandler: @escaping (Result<Progress, Error>) -> Void) -> Progress {}
```
When we 
update this function to use async/await, the previous pattern no longer composes as expected: 

```swift
public func makeSalad() async {
    let progress = Progress(totalUnitCount: 3) 
    let chopSubprogress = await chopFruits() 
    progress.addChild(chopSubprogress, withPendingUnitCount: 1) 
}

public func chopFruits() async -> Progress {}
```

The previous pattern of "returning" the `Progress` instance no longer composes as expected because we are forced to await the `chopFruits()` call before returning the `Progress` instance. However, the `Progress` instance that gets returned already has its `completedUnitCount` equal to `totalUnitCount`. This defeats its purpose of showing incremental progress as the code runs to completion within the method.

Additionally, while it may be possible to reuse the existing `Progress` to report progress in an `async` function by passing `Progress` as an argument to the function reporting progress, it is more error-prone, as shown below: 

```swift
let fruits = ["apple", "orange", "melon"]
let vegetables = ["spinach", "carrots", "celeries"]

public func makeSalad() async {
    let progress = Progress(totalUnitCount: 2)
    
    let choppingProgress = Progress()
    progress.addChild(subprogress, withPendingUnitCount: 1)
    
    await chopFruits(progress: subprogress)
    
    await chopVegetables(progress: subprogress) // Author's mistake: same subprogress was reused! 
}

public func chopFruits(progress: Progress) async {
    progress.totalUnitCount = Int64(fruits.count)
    for fruit in fruits {
        await chopItem(fruit)
        progress.completedUnitCount += 1
    }
}

public func chopVegetables(progress: Progress) async {
    progress.totalUnitCount = Int64(vegetables.count) // Author's mistake: overwriting progress made in `chopFruits` on the same `progress` instance!
    for vegetable in vegetables {
        await chopItem(vegetable)
        progress.completedUnitCount += 1
    }
}

public func chopItem(_ item: Ingredient) async {}
```

The existing `Progress` was not designed in a way that enforces the usage of `Progress` instance as a function parameter to report progress. Without a strong rule about who creates the `Progress` and who consumes it, it is easy to end up in a situation where the `Progress` is used more than once. This results in nondeterministic behavior when developers may accidentally overcomplete or overwrite a `Progress` instance. 

We introduce a new progress reporting mechanism following the new `ProgressReporter` type. This type encourages safer practices of progress reporting, separating what to be passed as parameter from what to be used to report progress.

This proposal outlines the use of `ProgressReporter` as reporters of progress and `~Copyable` `Subprogress` as parameters passed to progress reporting methods.

## Proposed solution and example

### Reporting Progress (General Operations)

To begin, let's create a framework called `SaladMaker` that contains functionalities that can make a salad and has built-in progress reporting. 

```swift 
struct Fruit {
    func chop() async { ... }
}

struct Dressing {
    func pour() async { ... } 
}

public class SaladMaker {
    
    let fruits: [Fruit]
    let dressings: [Dressing]
    
    public init() {
        fruits = [Fruit("apple"), Fruit("banana"), Fruit("cherry")]
        dressings = [Dressing("mayo"), Dressing("mustard"), Dressing("ketchup")]
    }
}
```

In order to report progress on subparts of making a salad, such as `chopFruits` and `mixDressings`, the framework methods each has a `Subprogress` parameter. The `Subprogress` parameter is also optional to provide developers the option to either opt-in to receiving progress updates when calling each of the methods. 

Within the methods thay report progress, each `Subprogress` passed into the subparts then has to be consumed to initialize an instance of `ProgressReporter`. This is done by calling `reporter(totalCount:)` on `Subprogress`. This can be done as follows:

```swift 
extension SaladMaker {

    private func chopFruits(progress: consuming Subprogress?) async {
        // Initialize a progress reporter to report progress on chopping fruits
        // with passed-in progress parameter
        let choppingReporter = progress?.reporter(totalCount: fruits.count)
        for fruit in fruits {
            await fruit.chop()
            choppingReporter?.complete(count: 1)
        }
    }
    
    private func mixDressings(progress: consuming Subprogress?) async {
        // Initialize a progress reporter to report progress on mixing dressing
        // with passed-in progress parameter
        let dressingReporter = progress?.reporter(totalCount: dressings.count)
        for dressing in dressings {
            await dressing.pour()
            dressingReporter?.complete(count: 1)
        }
    }
}
```

When a developer wants to use the `SaladMaker` framework and track the progress of making a salad, they can do so as follows: 

```swift 
func makeSalad() async {
    let saladMaker = SaladMaker()
    
    // Initialize a root-level `ProgressReporter` representing overall progress
    let overall = ProgressReporter(totalCount: 100)

    // Call `chopFruits` and opt-in to receive progress updates
    // by passing in a `Subprogress` constituting 70 count of overall progress
    await saladMaker.chopFruits(progress: overall.subprogress(assigningCount: 70))
    
    print("Chopped fruits, salad is \(overall.formatted(.fractionCompleted()))")
        
    // Call `mixDressings` and opt-in to receive progress updates
    // by passing in a `Subprogress` constituting 30 count of overall progress
    await saladMaker.mixDressings(progress: overall.subprogress(assigningCount: 30))
    
    print("Mixed dressings, salad is \(overall.formatted(.fractionCompleted()))")
}

await makeSalad()
```

### Reporting Progress (File-Related Operations)

With the use of @dynamicMemberLookup attribute, `ProgressReporter` is able to access properties that are not explicitly defined in the class. This means that developers are able to define additional properties on the class specific to the operations they are reporting progress on. For instance, we pre-define additional file-related properties on `ProgressReporter` by extending `ProgressReporter` for use cases of reporting progress on file operations.

>Note: The mechanisms of how extending `ProgressReporter` to include additional properties will be shown in the Detailed Design section of the proposal.

In this section, we will show an example of how we report progress with additional file-related properties:

To begin, let's create a class `ImageProcessor` that has the functionalities of downloading images and applying a filter onto images. 

```swift 
struct Image {
    let bytes: UInt64
    
    func download() async { ... }
    
    func applyFilter() async { ... }
}

final class ImageProcessor: Sendable {
    
    let images: [Image]
    
    init(images: [Image]) {
        self.images = images
    }
}
```

The method to download images would also report information such as `totalByteCount` along with the properties directly defined on a `ProgressReporter`. While `totalByteCount` is not directly defined on the `ProgressReporter` class, we can still set the property `totalByteCount` via the `withProperties` closure because this property can be discovered at runtime via the `@dynamicMemberLookup` attribute.

The subpart of applying filter does not contain additional file-related information, so we report progress on this subpart as usual.

Both the `downloadImagesFromDisk` and `applyFilterToImages` methods allow developers the option to receive progress updates while the tasks are carried out. 

```swift 
extension ImageProcessor {
    
    func downloadImagesFromDisk(progress: consuming Subprogress?) async {
        // Initialize a progress reporter to report progress on downloading images
        // with passed-in progress parameter
        let reporter = progress?.reporter(totalCount: images.count)
        
        // Initialize file-related properties on the reporter
        reporter?.withProperties { properties in
            properties.totalFileCount = images.count
            properties.totalByteCount = images.map { $0.bytes }.reduce(0, +)
        }
        
        for image in images {
            await image.download()
            reporter?.complete(count: 1)
            // Update each file-related property
            reporter?.withProperties { properties in
                properties.completedFileCount += 1
                properties.completedByteCount += image.bytes
            }
        }
    }
    
    func applyFilterToImages(progress: consuming Subprogress?) async {
        // Initializes a progress reporter to report progress on applying filter
        // with passed-in progress parameter
        let reporter = progress?.reporter(totalCount: images.count)
        for image in images {
            await image.applyFilter()
            reporter?.complete(count: 1)
        }
    }
}
```

When a developer wants to use the `ImageProcessor` framework to download images and apply filters on them, they can do so as follows: 

```swift 
func downloadImagesAndApplyFilter() async {
    let imageProcessor = ImageProcessor(images: [Image(bytes: 1000), Image(bytes: 2000), Image(bytes: 3000)]) 

    // Initialize a root-level `ProgressReporter` representing overall progress
    let overall = ProgressReporter(totalCount: 2)
    
    // Call `downloadImagesFromDisk` and opt-in to receive progress updates
    // by passing in a `Subprogress` constituting 1 count of overall progress
    await imageProcessor.downloadImagesFromDisk(progress: overall.subprogress(assigningCount: 1))
    
    // Call `applyFilterToImages` and opt-in to receive progress updates
    // by passing in a `Subprogress` constituting 1 count of overall progress
    await imageProcessor.applyFilterToImages(progress: overall.subprogress(assigningCount: 1))
}

await downloadImagesAndApplyFilter() 
```

### Advantages of using `Subprogress` as Currency Type

The advantages of `ProgressReporter` mainly derive from the use of `Subprogress` as a currency to create descendants of `ProgresssReporter`, and the recommended ways to use `Subprogress` are as follows: 

1. Pass `Subprogress` instead of `ProgressReporter` as a parameter to methods that report progress.

`Subprogress` should be used as the currency to be passed into progress-reporting methods, within which a child `ProgressReporter` instance that constitutes a portion of its parent's total units is created via a call to `reporter(totalCount:)`, as follows: 

```swift
func correctlyReportToSubprogressAfterInstantiatingReporter() async {
    let overall = ProgressReporter(totalCount: 2)
    await subTask(progress: overall.subprogress(assigningCount: 1))
}

func subTask(progress: consuming Subprogress) async {
    let count = 10
    let progressReporter = progress.reporter(totalCount: count) // returns an instance of ProgressReporter
    for _ in 1...count {
        progressReporter?.complete(count: 1) // reports progress as usual
    }
}
```

While developers may accidentally make the mistake of trying to report progress to a passed-in `Subprogress`, the fact that it does not have the same properties as an actual `ProgressReporter` means the compiler can inform developers when they are using either `ProgressReporter` or `Subprogress` wrongly. The only way for developers to kickstart actual progress reporting with `Subprogress` is by calling the `reporter(totalCount:)` to create a `ProgressReporter`, then subsequently call `complete(count:)` on `ProgressReporter`.

Each time before progress reporting happens, there needs to be a call to `reporter(totalCount:)`, which returns a `ProgressReporter` instance, before calling `complete(count:)` on the returned `ProgressReporter`. 

The following faulty example shows how reporting progress directly to `Subprogress` without initializing it will be cause a compiler error. Developers will always need to instantiate a `ProgressReporter` from `ProgresReporter.Progress` before reporting progress.  

```swift 
func incorrectlyReportToSubprogressWithoutInstantiatingReporter() async {
    let overall = ProgressReporter(totalCount: 2)
    await subTask(progress: overall.subprogress(assigningCount: 1))
}

func subTask(progress: consuming Subprogress) async {
    // COMPILER ERROR: Value of type 'Subprogress' has no member 'complete'
    progress.complete(count: 1)
}
```

2. Consume each `Subprogress` only once, and if not consumed, its parent `ProgressReporter` behaves as if none of its units were ever allocated to create `Subprogress`. 

Developers should create only one `Subprogress` for a corresponding to-be-instantiated `ProgressReporter` instance, as follows: 

```swift 
func correctlyConsumingSubprogress() {
    let overall = ProgressReporter(totalCount: 2)
    
    let progressOne = overall.subprogress(assigningCount: 1) // create one Subprogress
    let reporterOne = progressOne.reporter(totalCount: 10) // initialize ProgressReporter instance with 10 units
    
    let progressTwo = overall.subprogress(assigningCount: 1) //create one Subprogress
    let reporterTwo = progressTwo.reporter(totalCount: 8) // initialize ProgressReporter instance with 8 units 
}
```

It is impossible for developers to accidentally consume `Subprogress` more than once, because even if developers accidentally **type** out an expression to consume an already-consumed `Subprogress`, their code won't compile at all. 

The `reporter(totalCount:)` method, which **consumes** the `Subprogress`, can only be called once on each `Subprogress` instance. If there are more than one attempts to call `reporter(totalCount:)` on the same instance of `Subprogress`, the code will not compile due to the `~Copyable` nature of `Subprogress`. 

```swift 
func incorrectlyConsumingSubprogress() {
    let overall = ProgressReporter(totalCount: 2)
    
    let progressOne = overall.subprogress(assigningCount: 1) // create one Subprogress
    let reporterOne = progressOne.reporter(totalCount: 10) // initialize ProgressReporter instance with 10 units 

    // COMPILER ERROR: 'progressOne' consumed more than once
    let reporterTwo = progressOne.reporter(totalCount: 8) // initialize ProgressReporter instance with 8 units using same Progress 
}
```

### Interoperability with Existing `Progress` 

In both cases below, the propagation of progress of subparts to a root progress should work the same ways the existing `Progress` and `ProgressReporter` work.

Consider two progress reporting methods, one which utilizes the existing `Progress`, and another using `ProgressReporter`: 

```swift 
// Framework code: Function reporting progress with the existing `Progress`
func doSomethingWithProgress() -> Progress {
    let p = Progress.discreteProgress(totalUnitCount: 2)
    Task.detached {
        // do something
        p.completedUnitCount = 1 
        // do something
        p.completedUnitCount = 2
    }
    return p
}

// Framework code: Function reporting progress with `ProgressReporter` 
func doSomethingWithReporter(progress: consuming Subprogress) async -> Int {
    let reporter = progress.reporter(totalCount: 2)
    //do something
    reporter.complete(count: 1)
    //do something
    reporter.complete(count: 1)
}
```

In the case in which we need to receive a `Progress` instance and add it as a child to a `ProgressReporter` parent, we can use the interop method `subprogress(assigningCount: to:)`. 

The choice of naming the interop method as `subprogress(assigningCount: to:)` is to keep the syntax consistent with the method used to add a `ProgressReporter` instance to the progress tree, `subprogress(assigningCount:)`. An example of how these can be used to compose a `ProgressReporter` tree with a top-level `ProgressReporter` is as follows:

```swift 
// Developer code
func reporterParentProgressChildInterop() async {
    let overall = ProgressReporter(totalCount: 2) // Top-level `ProgressReporter`
    
    // Assigning 1 unit of overall's `totalCount` to `Subprogress`
    let progressOne = overall.subprogress(assigningCount: 1)
    // Passing `Subprogress` to method reporting progress
    let result = await doSomethingWithReporter(progress: progressOne)
    
    
    // Getting a `Progress` from method reporting progress
    let progressTwo = doSomethingWithProgress() 
    // Assigning 1 unit of overall's `totalCount` to the existing `Progress` 
    overall.subprogress(assigningCount: 1, to: progressTwo) 
}
```

The reverse case, in which a framework needs to receive a `ProgressReporter` instance as a child from a top-level `Progress`, can also be done. The interop method `makeChild(withPendingUnitCount: kind:)` added to `Progress` will support the explicit composition of a progress tree. 

The choice of naming the interop method as `makeChild(withPendingUnitCount: kind:)` is to keep the syntax consistent with the method used to add a `Foundation.Progress` instance as a child, `addChild(_: withPendingUnitCount:)`. An example of how this can be used to compose a `Foundation.Progress` tree with a top-level `Foundation.Progress` is as follows: 

```swift
// Developer code 
func progressParentReporterChildInterop() {
    let overall = Progress(totalUnitCount: 2)  // Top-level `Progress`
    
    // Getting a `Progress` from method reporting progress
    let progressOne = doSomethingWithProgress() 
    // Add Foundation's `Progress` as a child which takes up 1 unit of overall's `totalUnitCount`
    overall.addChild(progressOne, withPendingUnitCount: 1)
    
    // Getting a `Subprogress` which takes up 1 unit of overall's `totalUnitCount` 
    let progressTwo = overall.makeChild(withPendingUnitCount: 1)
    // Passing `Subprogress` instance to method reporting progress 
    doSomethingWithReporter(progress: progressTwo)
}
```

## Detailed design

### `ProgressReporter`

`ProgressReporter` is an Observable and Sendable class that developers use to report progress. Specifically, an instance of `ProgressReporter` can be used to either track progress of a single task, or track progress of a tree of `ProgressReporter` instances.

```swift
/// An object that conveys ongoing progress to the user for a specified task.
@available(FoundationPreview 6.2, *)
@Observable public final class ProgressReporter : Sendable, Hashable, Equatable, CustomDebugStringConvertible {
    
    /// The total units of work.
    public var totalCount: Int? { get }

    /// The completed units of work.
    /// If `self` is indeterminate, the value will be 0.
    public var completedCount: Int { get }

    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.
    public var fractionCompleted: Double { get }

    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool { get }

    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool { get }

    /// A type that conveys additional task-specific information on progress.
    public protocol Property {

        associatedtype T : Sendable
        
        /// The default value to return when property is not set to a specific value.
        static var defaultValue: T { get }

        /// Aggregates an array of `T` into a single value `T`.
        /// - Parameter all: Array of `T` to be aggregated.
        /// - Returns: A new instance of `T`.
        static func reduce(_ all: [T]) -> T
    }

    /// A container that holds values for properties that convey information about progress.
    @dynamicMemberLookup public struct Values : Sendable, CustomStringDebugConvertible {

        /// The total units of work.
        public var totalCount: Int? { mutating get set }

        /// The completed units of work. 
        public var completedCount: Int { mutating get set }
        
        /// Returns a property value that a key path indicates. If value is not defined, returns property's `defaultValue`. 
        public subscript<P>(dynamicMember key: KeyPath<ProgressReporter.Properties, P.Type>) -> P.T where P : ProgressReporter.Property { get set }
        
        /// Returns a debug description. 
        public static var debugDescription: String { get }
    }

    /// Initializes `self` with `totalCount`.
    ///
    /// If `totalCount` is set to `nil`, `self` is indeterminate.
    /// - Parameter totalCount: Total units of work.
    public convenience init(totalCount: Int?)

    /// Returns a `Subprogress` representing a portion of `self`which can be passed to any method that reports progress.
    ///
    /// - Parameter count: Units, which is a portion of `totalCount` delegated to an instance of `Subprogress`.
    /// - Returns: A `Subprogress` instance.
    public func subprogress(assigningCount portionOfParent: Int) -> Subprogress

    /// Increases `completedCount` by `count`.
    /// - Parameter count: Units of work.
    public func complete(count: Int)

    /// Accesses or mutates any properties that convey additional information about progress.
    public func withProperties<T>(_ closure: @Sendable (inout Values) throws -> T) rethrows -> T

    /// Returns a debug description. 
    public static var debugDescription: String { get }
}

/// Default implementation for `reduce` where T is `AdditiveArithmetic`. 
@available(FoundationPreview 6.2, *)
extension ProgressReporter.Property where Self.T : AdditiveArithmetic {
    /// Aggregates an array of `T` into a single value `T`.
    ///
    /// All `T` `AdditiveArithmetic` values are added together. 
    /// - Parameter all: Array of `T` to be aggregated.
    /// - Returns: A new instance of `T`.
    public static func reduce(_ all: [T]) -> T
}
```

### `ProgressReporter.Properties`

`ProgressReporter.Properties` is a struct that contains declarations of additional properties that are not defined directly on `ProgressReporter`, but discovered at runtime via `@dynamicMemberLookup`. These additional properties should be defined separately in `ProgressReporter` because neither are they used to drive forward progress like `totalCount` and `completedCount`, nor are they applicable in all cases of progress reporting.

We pre-declare some of these additional properties that are commonly desired in use cases of progress reporting such as `totalFileCount` and `totalByteCount`. 

For developers that would like to report additional metadata or properties as they use `ProgressReporter` to report progress, they will need to add declarations of their additional properties into `ProgressReporter.Properties`, similar to how the pre-declared additional properties are declared.

```swift
@available(FoundationPreview 6.2, *)
extension ProgressReporter {

extension ProgressReporter {

    public struct Properties {

        /// The total number of files.
        public var totalFileCount: TotalFileCount.Type { get }

        public struct TotalFileCount : Property {

            public typealias T = Int

            public static var defaultValue: Int { get }
        }

        /// The number of completed files.
        public var completedFileCount: CompletedFileCount.Type { get }

        public struct CompletedFileCount : Property {

            public typealias T = Int

            public static var defaultValue: Int { get }
        }

        /// The total number of bytes.
        public var totalByteCount: TotalByteCount.Type { get }

        public struct TotalByteCount : Property {

            public typealias T = UInt64

            public static var defaultValue: UInt64 { get }
        }

        /// The number of completed bytes.
        public var completedByteCount: CompletedByteCount.Type { get }

        public struct CompletedByteCount : Property {

            public typealias T = UInt64

            public static var defaultValue: UInt64 { get }
        }

        /// The throughput, in bytes per second.
        public var throughput: Throughput.Type { get }

        public struct Throughput : Property {

            public typealias T = UInt64

            public static var defaultValue: UInt64 { get }
        }

        /// The amount of time remaining in the processing of files.
        public var estimatedTimeRemaining: EstimatedTimeRemaining.Type { get }

        public struct EstimatedTimeRemaining : Property {

            public typealias T = Duration

            public static var defaultValue: Duration { get }
        }
    }
}
```

### `Subprogress`

An instance of `Subprogress` is returned from a call to `ProgressReporter`'s `subprogress(assigningCount:)`. `Subprogress` acts as an intermediary instance that you pass into functions that report progress. Additionally, callers should convert `Subprogress` to `ProgressReporter` before starting to report progress with it by calling `reporter(totalCount:)`. 

```swift
@available(FoundationPreview 6.2, *)
extension ProgressReporter {

    public struct Progress : ~Copyable, Sendable {
    
        /// Instantiates a ProgressReporter which is a child to the parent from which `self` is returned.
        /// - Parameter totalCount: Total count of returned child `ProgressReporter` instance.
        /// - Returns: A `ProgressReporter` instance.
        public consuming func reporter(totalCount: Int?) -> ProgressReporter
    }
}
```

### `ProgressReporter.FormatStyle` 

`ProgressReporter.FormatStyle` is used to configure the formatting of `ProgressReporter` into localized descriptions. You can specify which option to  format `ProgressReporter` with, and call the `format(_:)` method to get a localized string containing information that you have specified when initializing a `ProgressReporter.FormatStyle`.  

```swift
@available(FoundationPreview 6.2, *)
extension ProgressReporter {

    public struct FormatStyle : Codable, Equatable, Hashable {

        public struct Option : Codable, Hashable, Equatable {

            /// Option specifying `fractionCompleted`.
            ///
            /// For example, 20% completed.
            /// - Parameter style: A `FloatingPointFormatStyle<Double>.Percent` instance that should be used to format `fractionCompleted`.
            /// - Returns: A `LocalizedStringResource` for formatted `fractionCompleted`.
            public static func fractionCompleted(format style: FloatingPointFormatStyle<Double>.Percent = FloatingPointFormatStyle<Double>.Percent()) -> Option

            /// Option specifying `completedCount` / `totalCount`.
            ///
            /// For example, 5 of 10.
            /// - Parameter style: An `IntegerFormatStyle<Int>` instance that should be used to format `completedCount` and `totalCount`.
            /// - Returns: A `LocalizedStringResource` for formatted `completedCount` / `totalCount`.
            public static func count(format style: IntegerFormatStyle<Int> = IntegerFormatStyle<Int>()) -> Option
        }
        
        public var locale: Locale

        public init(_ option: Option, locale: Locale = .autoupdatingCurrent)
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressReporter.FormatStyle : FormatStyle {

    public func locale(_ locale: Locale) -> ProgressReporter.FormatStyle

    public func format(_ reporter: ProgressReporter) -> String
}
```

To provide convenience methods for formatting `ProgressReporter`, we also provide the `formatted(_:)` method that developers can call on any `ProgressReporter`.

```swift
@available(FoundationPreview 6.2, *)
extension ProgressReporter {

    public func formatted<F>(_ style: F) -> F.FormatOutput where F : FormatStyle, F.FormatInput == ProgressReporter
}

@available(FoundationPreview 6.2, *)
extension FormatStyle where Self == ProgressReporter.FormatStyle {

    public static func fractionCompleted(format: FloatingPointFormatStyle<Double>.Percent) -> Self

    public static func count(format: IntegerFormatStyle<Int>) -> Self    
}
```

### `ProgressReporter.FileFormatStyle`

The custom format style for additional file-related properties are also implemented as follows: 

```swift 
@available(FoundationPreview 6.2, *)
extension ProgressReporter {

    public struct FileFormatStyle : Codable, Equatable, Hashable {

        public struct Options : Codable, Equatable, Hashable {

            /// Option specifying all file-related properties.
            public static var file: Option { get }
        }

        public var locale: Locale

        public init(_ option: Options, locale: Locale = .autoupdatingCurrent)
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressReporter.FileFormatStyle : FormatStyle {

    public func locale(_ locale: Locale) -> ProgressReporter.FileFormatStyle

    public func format(_ reporter: ProgressReporter) -> String
}

@available(FoundationPreview 6.2, *)
extension FormatStyle where Self == ProgressReporter.FileFormatStyle {

    public static var file: Self { get }
}
```

### Methods for Interoperability with Existing `Progress` 

To allow frameworks which may have dependencies on the pre-existing progress-reporting protocol to adopt this new progress-reporting protocol, either as a recipient of a child `Progress` instance that needs to be added to its `ProgressReporter` tree, or as a provider of `ProgressReporter` that may later be added to another framework's `Progress` tree, there needs to be additional support for ensuring that progress trees can be composed with in two cases: 
1. A `ProgressReporter` instance has to parent a `Progress` child
2. A `Progress` instance has to parent a `ProgressReporter` child 

#### ProgressReporter (Parent) - Progress (Child)

To add an instance of `Progress` as a child to an instance of `ProgressReporter`, we pass an `Int` for the portion of `ProgressReporter`'s `totalCount` `Progress` should take up and a `Progress` instance to `subprogress(assigningCount: to:)`. The `ProgressReporter` instance will track the `Progress` instance just like any of its `ProgressReporter` children.

```swift 
@available(FoundationPreview 6.2, *)
extension ProgressReporter {
    // Adds a `Progress` instance as a child which constitutes a certain `count` of `self`'s `totalCount`.
    /// - Parameters:
    ///   - count: Number of units delegated from `self`'s `totalCount`.
    ///   - progress: `Progress` which receives the delegated `count`.
    public func subprogress(assigningCount: Int, to progress: Foundation.Progress)
}
```

#### Progress (Parent) - ProgressReporter (Child) 

To add an instance of `ProgressReporter` as a child to an instance of the existing `Progress`, the `Progress` instance calls `makeChild(count:kind:)` to get a `Subprogress` instance that can be passed as a parameter to a function that reports progress. The `Progress` instance will track the `ProgressReporter` instance as a child, just like any of its `Progress` children. 

```swift 
@available(FoundationPreview 6.2, *)
extension Progress {
    /// Returns a Subprogress which can be passed to any method that reports progress
    /// and can be initialized into a child `ProgressReporter` to the `self`.
    ///
    /// Delegates a portion of totalUnitCount to a future child `ProgressReporter` instance.
    ///
    /// - Parameter count: Number of units delegated to a child instance of `ProgressReporter`
    /// which may be instantiated by `Subprogress` later when `reporter(totalCount:)` is called.
    /// - Returns: A `Subprogress` instance.
    public func makeChild(withPendingUnitCount count: Int) -> Subprogress
}
```

## Impact on existing code

There should be no impact on existing code, as this is an additive change. 

However, this new progress reporting API, `ProgressReporter`, which is compatible with Swift's async/await style concurrency, will be favored over the existing `Progress` API going forward. Depending on how widespread the adoption of `ProgressReporter` is, we may consider deprecating the existing `Progress` API. 

## Future Directions 

### Additional Overloads to APIs within UI Frameworks 
To enable wider adoption of `ProgressReporter`, we can add overloads to APIs within UI frameworks that has been using Foundation's `Progress`, such as `ProgressView` in SwiftUI. Adding support to existing progress-related APIs within UI Frameworks will enable adoption of `ProgressReporter` for app developers who wish to do extensive progress reporting and show progress on the User Interface using `ProgressReporter`. 

### Distributed `ProgressReporter`
To enable inter-process progress reporting, we would like to introduce distributed `ProgressReporter` in the future, which would functionally be similar to how Foundation's `Progress` mechanism for reporting progress across processes.

### Enhanced `FormatStyle`
To enable more customization of `ProgressReporter`, we would like to introduce more options in `ProgressReporter`'s `FormatStyle`.

## Alternatives considered

### Alternative Names
As the existing `Progress` already exists, we had to come up with a name other than `Progress` for this API, but one that still conveys the progress-reporting functionality of this API. Some of the names we have considered are as follows: 

1. Alternative to `ProgressReporter` 
    - `AsyncProgress`  

We decided to proceed with the name `ProgressReporter` because prefixing an API with the term `Async` may be confusing for developers, as there is a precedent of APIs doing so, such as `AsyncSequence` adding asynchronicity to `Sequence`, whereas this is a different case for `ProgressReporter` vs `Progress`.  
    
2. Alternative to `Subprogress` 
    - `ProgressReporter.Link`
    - `ProgressReporter.Child` 
    - `ProgressReporter.Token`
    - `ProgressReporter.Progress`  
    
While the names `Link`, `Child`, and `Token` may appeal to the fact that this is a type that is separate from the `ProgressReporter` itself and should only be used as a function parameter and to be consumed immediately to kickstart progress reporting, it is ambiguous because developers may not immedidately figure out its function from just the name itself. While `Progress` may be a good name to indicate to developers that any method receiving `Progress` as a parameter reports progress, it is does not accurately convey its nature of being the bearer of a certain portion of some parent's `totalCount`. We landed at `Subprogress` as it serves as an indicator for developers that methods with a `Subprogress` parameter reports progress, and at the same time conveys the correct idea that it is meant to be a part of a progress tree.

3. Alternative to `subprogress(assigningCount:)` 
    - `assign(count:)`

We initially considered naming the method that returns a `Subprogress` instance `assign(count:)` due to its nature of being a peer method to `complete(count:)`. However, `assign` does not intuitively indicate to developers that this method is supposed to return anything, so we decided on naming the method `subprogress` and its argument `assigningCount` to indicate that it is assigning a portion of its own `totalCount` to a `Subprogress` instance. 
    
### Introduce `ProgressReporter` to Swift standard library
In consideration for making `ProgressReporter` a lightweight API for server-side developers to use without importing the entire `Foundation` framework, we considered either introducing `ProgressReporter` in a standalone module, or including `ProgressReporter` in existing Swift standard library modules such as `Observation` or `Concurrency`. However, given the fact that `ProgressReporter` has dependencies in `Observation` and `Concurrency` modules, and that the goal is to eventually support progress reporting over XPC connections, `Foundation` framework is the most ideal place to host the `ProgressReporter` as it is the central framework for APIs that provide core functionalities when these functionalities are not provided by Swift standard library and its modules.

### Implement `ProgressReporter` as a Generic Class
In Version 1 of this proposal, we proposed implementing `ProgressReporter` as a generic class, which has a type parameter `Properties`, which conforms to the protocol `ProgressProperties`. In this case, the API reads as `ProgressReporter<Properties>`. This was implemented as such to account for additional properties required in different use cases of progress reporting. For instance, `FileProgressProperties` is a type of `ProgressProperties` that holds references to properties related to file operations such as `totalByteCount` and `totalFileCount`. The `ProgressReporter` class itself will then have a `properties` property, which holds a reference to its `Properties` struct, in order to access additional properties via dot syntax, which would read as `reporter.properties.totalByteCount`. In this implementation, the typealiases introduced are as follows: 

    ```swift 
    public typealias BasicProgressReporter = ProgressReporter<BasicProgressProperties>
    public typealias FileProgressReporter = ProgressReporter<FileProgressProperties>
    public typealias FileProgress = ProgressReporter<FileProgressProperties>.Progress
    public typealias BasicProgress = ProgressReporter<BasicProgressProperties>.Progress
    ``` 
    
However, while this provides flexibility for developers to create any custom types of `ProgressReporter`, some issues that arise include the additional properties of a child `ProgressReporter` being inaccessible by its parent `ProgressReporter` if they were not of the same type. For instance, if the child is a `FileProgressReporter` while the parent is a `BasicProgressReporter`, the parent does not have access to the child's `FileProgressProperties` because it only has reference to its own `BasicProgressProperties`. This means that developers would not be able to display additional file-related properties reported by its child in its localized descriptions without an extra step of adding a layer of children to parent different types of children in the progress reporter tree. 

We decided to replace the generic class implementation with `@dynamicMemberLookup`, making the `ProgressReporter` class non-generic, and instead relies on `@dynamicMemberLookup` to access additional properties that developers may want to use in progress reporting. This allows `ProgressReporter` to all be of the same `Type`, and at the same time retains the benefits of being able to report progress with additional properties such as `totalByteCount` and `totalFileCount`. With all progress reporters in a tree being the same type, a top-level `ProgressReporter` can access any additional properties reported by its children `ProgressReporter` without much trouble as compared to if `ProgressReporter` were to be a generic class.

### Implement `ProgressReporter` as an actor
We considered implementing `ProgressReporter` as we want to maintain this API as a reference type that is safe to use in concurrent environments. However, if `ProgressReporter` were to be implemented, `ProgressReporter` will not be able to conform to `Observable` because actor-based keypaths do not exist as of now. Ensuring that `ProgressReporter` is `Observable` is important to us, as we want to ensure that `ProgressReporter` works well with UI components in SwiftUI. 

### Implement `ProgressReporter` as a protocol
In consideration of making the surface of the API simpler without the use of generics, we considered implementing `ProgressReporter` as a protocol, and provide implementations for specialized `ProgressReporter` classes that conform to the protocol, namely `BasicProgress`(`ProgressReporter` for progress reporting with only simple `count`) and `FileProgress` (`ProgressReporter` for progress reporting with file-related additional properties such as `totalFileCount`). This had the benefit of developers having to initialize a `ProgressReporter` instance with `BasicProgress(totalCount: 10)` instead of `ProgressReporter<BasicProgressProperties>(totalCount: 10)`.  

However, one of the downside of this is that every time a developer wants to create a `ProgressReporter` that contains additional properties that are tailored to their use case, they would have to write an entire class that conforms to the `ProgressReporter` protocol from scratch, including the calculations of `fractionCompleted` for `ProgressReporter` trees. Additionally, the `~Copyable` struct nested within the `ProgressReporter` class that should be used as function parameter passed to functions that report progress will have to be included in the `ProgressReporter` protocol as an `associatedtype` that is `~Copyable`. However, the Swift compiler currently cannot suppress 'Copyable' requirement of an associated type and developers will need to consciously work around this. These create a lot of overload for developers wishing to report progress with additional metadata beyond what we provide in `BasicProgress` and `FileProgress` in this case. 

### Introduce an `Observable` adapter for `ProgressReporter`
We thought about introducing a clearer separation of responsibility between the reporting and observing of a `ProgressReporter`, because progress reporting is often done by the framework, and the caller of a certain method of a framework would merely observe the `ProgressReporter` within the framework. This will deter observers from accidentally mutating values of a framework's `ProgressReporter`. 

However, this means that `ProgressReporter` needs to be passed into the `Observable` adapter to make an instance `ObservableProgressReporter`, which can then be passed into `ProgressView()` later. We decided that this is too much overhead for developers to use for the benefit of avoiding observers from mutating values of `ProgressReporter`. 

### Introduce Method to Generate Localized Description
We considered introducing a `localizedDescription(including:)` method, which returns a `LocalizedStringResource` for observers to get custom format descriptions for `ProgressReporter`. In contrast, using a `FormatStyle` aligns more closely with Swift's API, and has more flexibility for developers to add custom `FormatStyle` to display localized descriptions for additional properties they may want to declare and use. 

### Introduce Explicit Support for Cancellation, Pausing, and Resuming of `ProgressReporter`
The existing `Progress` provides support for cancelling, pausing and resuming an ongoing operation tracked by an instance of `Progress`, and propagates these actions down to all of its children. We decided to not introduce support for this behavior as there is support in cancelling a `Task` via `Task.cancel()` in Swift structured concurrency. The absence of support for cancellation, pausing and resuming in `ProgressReporter` helps to clarify the scope of responsibility of this API, which is to report progress, instead of owning a task and performing actions on it.

### Check Task Cancellation within `complete(count:)` Method
We considered adding a `Task.isCancelled` check in the `complete(count:)` method so that calls to `complete(count:)` from a `Task` that is cancelled becomes a no-op. This means that once a Task is cancelled, calls to `complete(count:)` from within the task does not make any further incremental progress. 

We decided to remove this check to transfer the responsibility back to the developer to not report progress further from within a cancelled task. Typically, developers complete some expensive async work and subsequently updates the `completedCount` of a `ProgressReporter` by calling `complete(count:)`. Checking `Task.isCancelled` means that we take care of the cancellation by not making any further incremental progress, but developers are still responsible for the making sure that they do not execute any of the expensive async work. Removing the `Task.isCancelled` check from `complete(count:)` helps to make clear that developers will be responsible for both canceling any expensive async work and any further update to `completedCount` of `ProgressReporter` when `Task.isCancelled` returns `true`.  

### Introduce `totalCount` and `completedCount` properties as `UInt64`
We considered using `UInt64` as the type for `totalCount` and `completedCount` to support the case where developers use `totalCount` and `completedCount` to track downloads of larger files on 32-bit platforms byte-by-byte. However, developers are not encouraged to update progress byte-by-byte, and should instead set the counts to the granularity at which they want progress to be visibly updated. For instance, instead of updating the download progress of a 10,000 bytes file in a byte-by-byte fashion, developers can instead update the count by 1 for every 1,000 bytes that has been downloaded. In this case, developers set the `totalCount` to 10 instead of 10,000. To account for cases in which developers may want to report the current number of bytes downloaded, we added `totalByteCount` and `completedByteCount` to `FileProgressProperties`, which developers can set and display within `localizedDescription`.

### Store Existing `Progress` in TaskLocal Storage
This would allow a `Progress` object to be stored in Swift `TaskLocal` storage. This allows the implicit model of building a progress tree to be used from Swift Concurrency asynchronous contexts. In this solution, getting the current `Progress` and adding a child `Progress` is done by first reading from TaskLocal storage when called from a Swift Concurrency context. This method was found to be not preferable as we would like to encourage the usage of the explicit model of Progress Reporting, in which we do not depend on an implicit TaskLocal storage and have methods that report progress to explicitly accepts a `Progress` object as a parameter. 

### Add Convenience Method to Existing `Progress` for Easier Instantiation of Child Progress
While the explicit model has concurrency support via completion handlers, the usage pattern does not fit well with async/await, because which an instance of `Progress` returned by an asynchronous function would return after code is executed to completion. In the explicit model, to add a child to a parent progress, we pass an instantiated child progress object into the `addChild(child:withPendingUnitCount:)` method. In this alternative, we add a convenience method that bears the function signature `makeChild(pendingUnitCount:)` to the `Progress` class. This method instantiates an empty progress and adds itself as a child, allowing developers to add a child progress to a parent progress without having to instantiate a child progress themselves. The additional method reads as follows: 

```swift
extension Progress {
    public func makeChild(pendingUnitCount: Int64) -> Progress {
        let child = Progress()
        addChild(child, withPendingUnitCount: pendingUnitCount)
        return child
    }
}
```
This method would mean that we are altering the usage pattern of pre-existing `Progress` API, which may introduce more confusions to developers in their efforts to move from non-async functions to async functions.

### Allow for Assignment of `ProgressReporter` to Multiple Progress Reporter Trees
The ability to assign a `ProgressReporter` to be part of multiple progress trees means allowing for a `ProgressReporter` to have more than one parent, would enable developers the flexibility to model any type of progress relationships. 

However, allowing the freedom to add a ProgressReporter to more than one tree compromises the safety guarantee we want to provide in this API. The main safety guarantee we provide via this API is that `ProgressReporter` will not be used more than once because it is always instantiated from calling reporter(totalCount:) on a ~Copyable `Subprogress` instance.

### Replace Count-based Relationships between `ProgressReporter` 
The progress-reporting functionality = of each `ProgressReporter` depends on the `totalCount` and `completedCount` properties, both of which are integers. This puts the responsibility onto the developers to make sure that all `assignedCount` add up to the `totalCount` for a correct progress reporting at the top level.  

While there are considerations to move away from this due to the extra attention required from developers in refactoring code, `fractionCompleted`, which is a `Double` value, has the most precision when computed from integers. 

### Introduce Additional Convenience for Getting `Subprogress` 
We considered introducing a convenience for getting `Subprogress` by calling `subprogress()` without specifying `assigningCount` as an argument. In this case, the `Subprogress` returned will automatically be assigned 1 count of its parent's `totalCount` and parent's `totalCount` will automatically increase by 1. 

However, this convenience would introduce more confusion with developers when they try to use `subprogress()` and `subprogress(assigningCount:)` next to each other because `subprogress(assigningCount:)` does not automatically increase the parent's `totalCount`: 

```swift 
// Developer code 
let overall = ProgressReporter(totalCount: nil) 
await doSomething(overall.assign()) // totalCount: nil -> 1, assignedCount: 0 -> 1 
await doSomething(overall.assign(count: 2)) // totalCount: 1 (doesn't increase), assignedCount: 1 -> 3 
```

## Acknowledgements 
Thanks to 
- [Tony Parker](https://github.com/parkera),
- [Tina Liu](https://github.com/itingliu),
- [Jeremy Schonfeld](https://github.com/jmschonfeld),
- [Charles Hu](https://github.com/iCharlesHu)  
for constant feedback and guidance throughout to help shape this API and proposal. 
    
Thanks to
- [Cassie Jones](https://github.com/porglezomp), 
- [Konrad Malawski](https://github.com/ktoso), 
- [Philippe Hausler](https://github.com/phausler), 
- Julia Vashchenko  
for valuable feedback on this proposal and its previous versions.
    
Thanks to 
- [Konrad Malawski](https://github.com/ktoso), 
- [Matt Ricketson](https://github.com/ricketson)  
for prior efforts on ideation of a progress reporting mechanism compatible with Swift concurrency. 
