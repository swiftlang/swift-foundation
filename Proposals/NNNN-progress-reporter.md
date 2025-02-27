# `ProgressReporter`: Progress Reporting in Swift Concurrency  

* Proposal: SF-NNNN
* Author(s): [Chloe Yeo](https://github.com/chloe-yeo)
* Review Manager: TBD
* Status: **Draft**

## Revision history

* **v1** Initial version

## Table of Contents 

* [Introduction](#introduction)
* [Motivation](#motivation)
* [Proposed Solution and Example](#proposed-solution-and-example)
    * [Reporting Progress with Identical Properties](#reporting-progress-with-identical-properties)
    * [Reporting Progress with Distinct Properties](#reporting-progress-with-distinct-properties)
    * [Reporting Progress with Task Cancellation](#reporting-progress-with-task-cancellation)
    * [Advantages of using `ProgressReporter.Progress` as Currency Type](#advantages-of-using-progresssreporterprogress-as-currency-type)
    * [Interoperability with Foundation\'s `Progress`](#interoperability-with-foundations-progress)
* [Detailed Design](#detailed-design)
    * [`ProgressProperties`](#progressproperties)
        * [`BasicProgressProperties`](#basicprogressproperties)
        * [`FileProgressProperties`](#fileprogressproperties)
    * [`ProgressReporter`](#progressreporter)
    * [`ProgressReporter.Progress`](#progressreporterprogress)
    * [Interoperability with Foundation's `Progress`](#methods-for-interoperability-with-foundations-progress)
        * [`ProgressReporter` \(Parent\) \- `Progress` \(Child\)](#progressreporter-parent---progress-child)
        * [`Progress` \(Parent\) \- `ProgressReporter` \(Child\)](#progress-parent---progressreporter-child)
* [Impact on Existing Code](#impact-on-existing-code)
* [Future Directions](#future-directions)
    * [Additional Overloads to APIs within UI Frameworks](#additional-overloads-to-apis-within-ui- frameworks)
    * [Distributed ProgressReporter](#distributed-progressreporter)
* [Alternatives Considered](#alternatives-considered)
    * [Alternative Names](#alternative-names)
    * [Introduce `ProgressReporter` to Swift standard library](#introduce-progressreporter-to-swift-standard-library)
    * [Implement `ProgressReporter` as an actor](#implement-progressreporter-as-an-actor)
    * [Implement `ProgressReporter` as a protocol](#implement-progressreporter-as-a-protocol)
    * [Introduce an Observable adapter for `ProgressReporter`](#introduce-an-observable-adapter-for-progressreporter)
    * [Introduce Support for Cancellation, Pausing, Resuming of `ProgressReporter`](#introduce-support-for-cancellation-pausing-and-resuming-of-progressreporter)
    * [Move totalCount and completedCount properties to `ProgressProperties` protocol](#move-totalcount-and-completedcount-properties-to-progressproperties-protocol)
    * [Introduce totalCount and completedCount properties as UInt64](#introduce-totalcount-and-completedcount-properties-as-uint64)
    * [Store Foundation\'s `Progress` in TaskLocal Storage](#store-foundations-progress-in-tasklocal-storage)
    * [Add Convenience Method to Foundation\'s `Progress` for Easier Instantiation of Child Progress](#add-convenience-method-to-foundations-progress-for-easier-instantiation-of-child-progress)
* [Acknowledgements](#acknowledgements)

## Introduction

Progress reporting is a generally useful concept, and can be helpful in all kinds of applications: from high level UIs, to simple command line tools, and more.

Foundation offers a progress reporting mechanism that has been very popular with application developers on Apple platforms. The existing `Progress` class provides a self-contained, tree-based mechanism for progress reporting and is adopted in various APIs which are able to report progress. The functionality of the `Progress` class is two-fold –– it reports progress at the code level, and at the same time, displays progress at the User Interface level. While the recommended usage pattern of `Progress` works well with Cocoa's completion-handler-based async APIs, it does not fit well with Swift's concurrency support via async/await.

This proposal aims to introduce an efficient, easy-to-use, less error-prone Progress Reporting API —— `ProgressReporter` —— that is compatible with async/await style concurrency to Foundation. To further support the use of this Progress Reporting API with high-level UIs, this API is also `Observable`. 

## Motivation

A progress reporting mechanism that is compatible with Swift's async/await style concurrency would be to pass a `Progress` instance as a parameter to functions or methods that report progress. The current recommended usage pattern of Foundation's `Progress`, as outlined in [Apple Developer Documentation](https://developer.apple.com/documentation/foundation/progress), does not fit well with async/await style concurrency. Typically, a function that aims to report progress to its callers will first return an instance of Foundation's `Progress`. The returned instance is then added as a child to a parent `Progress` instance. 

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

When we update this function to use async/await, the previous pattern no longer composes as expected: 

```swift
public func makeSalad() async {
    let progress = Progress(totalUnitCount: 3) 
    let chopSubprogress = await chopFruits() 
    progress.addChild(chopSubprogress, withPendingUnitCount: 1) 
}

public func chopFruits() async -> Progress {}
```

The previous pattern of "returning" the `Progress` instance no longer composes as expected because we are forced to await the `chopFruits()` call. We could _then_ return the `Progress` instance. However, the `Progress` instance that gets returned already has its `completedUnitCount` equal to `totalUnitCount`. This defeats its purpose of showing incremental progress as the code runs to completion within the method.

Additionally, while it may be possible to reuse Foundation's `Progress` to report progress in an `async` function by passing `Progress` as an argument to the function reporting progress, it is more error-prone, as shown below: 

```swift
let fruits = ["apple", "orange", "melon"]
let vegetables = ["spinach", "carrots", "celeries"]

public func makeSalad() async {
    let progress = Progress(totalUnitCount: 2)
    
    let subprogress = Progress()
    progress.addChild(subprogress, withPendingUnitCount: 1)
    
    await chopFruits(progress: subprogress)
    
    await chopVegetables(progress: subprogress) // Author's Mistake, same subprogress was passed!
}

public func chopFruits(progress: Progress) async {
    progress.totalUnitCount = Int64(fruits.count)
    for fruit in fruits {
        await chopItem(fruit)
        progress.completedUnitCount += 1
    }
}

public func chopVegetables(progress: Progress) async {
    progress.totalUnitCount = Int64(vegetables.count) // Author's Mistake, overrides progress made in chopFruits as same subprogress was passed!
    for vegetable in vegetables {
        await chopItem(vegetable)
        progress.completedUnitCount += 1
    }
}

public func chopItem(_ item: String) async {}
```

The existing `Progress` in Foundation was not designed in a way that enforces the usage of `Progress` instance as a function parameter to report progress. Without a strong rule about who creates the `Progress` and who consumes it, it is easy to end up in a situation where the `Progress` is used more than once. This results in nondeterministic behavior when developers may accidentally overcomplete or override a `Progress` instance. 

In contrast, the introduction of a new progress reporting mechanism following the new `ProgressReporter` type would enforce safer practices of progress reporting via a strong rule of what should be passed as parameter and what should be used to report progress. 

This proposal outlines the use of `ProgressReporter` as reporters of progress and `~Copyable` `ProgressReporter.Progress` as parameters passed to progress reporting methods.

## Proposed solution and example

Before proceeding further with this proposal, it is important to keep in mind the type aliases introduced with this API. The examples outlined in the following sections will utilize type aliases as follows: 

```swift
public typealias BasicProgressReporter = ProgressReporter<BasicProgressProperties>
public typealias FileProgressReporter = ProgressReporter<FileProgressProperties>

public typealias FileProgress = ProgressReporter<FileProgressProperties>.Progress
public typealias BasicProgress = ProgressReporter<BasicProgressProperties>.Progress
```

### Reporting Progress With Identical Properties

To begin, let's create a class called `MakeSalad` that reports progress made on a salad while it is being made. 

```swift 
struct Fruit {
    let name: String 
    
    init(_ fruit: String) {
        self.name = fruit
    }
    
    func chop() async {}
}

struct Dressing {
    let name: String 
    
    init (_ dressing: String) {
        self.name = dressing 
    }
    
    func pour() async {} 
}

public class MakeSalad {
    
    let overall: BasicProgressReporter
    let fruits: [Fruit]
    let dressings: [Dressing]
    
    public init() {
        overall = BasicProgressReporter(totalCount: 100)
        fruits = [Fruit("apple"), Fruit("banana"), Fruit("cherry")]
        dressings = [Dressing("mayo"), Dressing("mustard"), Dressing("ketchup")]
    }
}
```

In order to report progress on subparts of making a salad, such as `chopFruits` and `mixDressings`, we can instantitate subprogresses by passing an instance of `ProgressReporter.Progress` to each subpart. Each `ProgressReporter.Progress` passed into the subparts then have to be consumed to initialize an instance of `ProgressReporter`. This is done by calling `reporter(totalCount:)` on `ProgressReporter.Progress`. These child progresses will automatically contribute to the `overall` progress reporter within the class, due to established parent-children relationships between `overall` and the reporters of subparts. This can be done as follows:

```swift 
extension MakeSalad {

    public func start() async -> String {
        // Gets a BasicProgress instance with 70 portioned count from `overall` 
        let fruitsProgress = overall.assign(count: 70)
        await chopFruits(progress: fruitsProgress)
        
        // Gets a BasicProgress instance with 30 portioned count from `overall`
        let dressingsProgress = overall.assign(count: 30)
        await mixDressings(progress: dressingsProgress)
        
        return "Salad is ready!"
    }
    
    private func chopFruits(progress: consuming BasicProgress?) async {
        // Initializes a progress reporter to report progress on chopping fruits 
        // with passed-in progress parameter 
        let choppingReporter = progress?.reporter(totalCount: fruits.count)
        for fruit in fruits {
            await fruit.chop()
            choppingReporter?.complete(count: 1)
        }
    }
    
    private func mixDressings(progress: consuming BasicProgress?) async {
        // Initializes a progress reporter to report progress on mixing dressing 
        // with passed-in progress parameter 
        let dressingReporter = progress?.reporter(totalCount: dressings.count)
        for dressing in dressings {
            await dressing.pour()
            dressingReporter?.complete(count: 1)
        }
    }
}
```

### Reporting Progress With Distinct Properties

`ProgressReporter`, which is a generic class, allows developers to define their own type of `ProgressProperties`, and report progress with additional metadata or properties. We propose adding `BasicProgressProperties` for essential use cases and a `FileProgressProperties` for reporting progress on file-related operations. Developers can create progress trees in which all instances of `ProgressReporter` are of the same kind, or a mix of `ProgressReporter` instances with different `ProgressProperties`.

In this section, we will show an example of how progress reporting with different kinds of `ProgressReporter` can be done. To report progress on both making salad and downloading images, developers can use both `BasicProgressReporter` and `FileProgressReporter` which are children reporters to an overall `BasicProgressReporter`, as follows: 

```swift 
struct Fruit {
    let name: String 
    
    init(_ fruit: String) {
        self.name = fruit
    }
    
    func chop() async {}
}

struct Image {

    let bytes: Int
    
    init(bytes: Int) {
        self.bytes = bytes
    }
    
    func read() async {}
}

class Multitask {

    let overall: BasicProgressReporter
    // These are stored in this class to keep track of 
    // additional properties of reporters of chopFruits and downloadImages
    var chopFruits: BasicProgressReporter?
    var downloadImages: FileProgressReporter?
    let fruits: [Fruit]
    let images: [Image]
    
    init() {
        overall = BasicProgressReporter(totalCount: 100)
        fruits = [Fruit("apple"), Fruit("banana"), Fruit("cherry")]
        images = [Image(bytes: 1000), Image(bytes: 2000), Image(bytes: 3000)]
    }
    
    func chopFruitsAndDownloadImages() async {
        // Gets a BasicProgress instance with 50 portioned count from `overall` 
        let chopProgress = overall.assign(count: 50)
        await chop(progress: chopProgress)
        
        // Gets a FileProgress instance with 50 portioned count from `overall` 
        let downloadProgress = overall.assign(count: 50, kind: FileProgressProperties.self)
        await download(progress: downloadProgress)
    }
}
```

Here's how you can compose two different kinds of progress into the same tree, with `overall` being the top-level `ProgressReporter`.  `overall` has two children — `chopFruits` of Type `BasicProgressReporter`, and `downloadImages` of Type `FileProgressReporter`. You can report progress to both `chopFruits` and `downloadImages` as follows: 

```swift
extension Multitask {

    func chop(progress: consuming BasicProgress?) async {
        // Initializes a BasicProgressReporter to report progress on chopping fruits
        // with passed-in `progress` parameter 
        chopReporter = progress?.reporter(totalCount: fruits.count)
        for fruit in fruits {
            await fruit.chop()
            chopReporter?.complete(count: 1)
        }
    }

    func download(progress: consuming FileProgress?) async {
        // Initializes a FileProgressReporter to report progress on file downloads 
        // with passed-in `progress` parameter
        downloadReporter = progress?.reporter(totalCount: images.count, properties: FileProgressProperties())
        for image in images {
            if let reporter = downloadReporter {
                // Passes in a FileProgress instance with 1 portioned count from `downloadImages`
                await read(image,  progress: reporter.assign(count: 1))
            }
        }
    }

    func read(_ image: Image, progress: consuming FileProgress?) async {
        // Instantiates a FileProgressProperties with known properties 
        // to be passed into `reporter(totalCount: properties:)`
        let fileProperties = FileProgressProperties(totalFileCount: 1, totalByteCount: image.bytes)
        
        // Initializes a FileProgressReporter with passed-in `progress` parameter
        let readFile = progress?.reporter(totalCount: 1, properties: fileProperties)
        
        // Initializes other file-related properties of `readFile` that are only obtained later 
        readFile?.properties.throughput = calculateThroughput()
        readFile?.properties.estimatedTimeRemaining = calculateEstimatedTimeRemaining()
        
        await image.read()
        
        // Updates file-related properties of `readFile` 
        readFile?.properties.completedFileCount += 1
        readFile?.properties.completedByteCount += image.bytes
        
        // Completes `readFile` entirely
        readFile?.complete(count: 1)
    }
}
```

### Reporting Progress with Task Cancellation

A `ProgressReporter` running in a `Task` can respond to the cancellation of the `Task`. In structured concurrency, cancellation of the parent task results in the cancellation of all child tasks. Mirroring this behavior, a `ProgressReporter` running in a parent `Task` that is cancelled will have its children instances of `ProgressReporter` cancelled as well. 

Cancellation in the context of `ProgressReporter` means that any subsequent calls to `complete(count:)` after a `ProgressReporter` is cancelled results in a no-op. Trying to update 'cancelled' `ProgressReporter` and its children will no longer increase `completedCount`, thus no further forward progress will be made.

While the code can continue running, calls to `complete(count:)` from a `Task` that is cancelled will result in a no-op, as follows: 

```swift
let fruits = ["apple", "banana", "cherry"]
let overall = BasicProgressReporter(totalCount: fruits.count)

func chopFruits(_ fruits: [String]) async -> [String] {
    await withTaskGroup { group in
                
        // Concurrently chop fruits
        for fruit in fruits {
            group.addTask {
                await FoodProcessor.chopFruit(fruit: fruit, progress: overall.assign(count: 1))
            }
            if fruit == "banana" {
                group.cancelAll()
            }
        }
        
        // Collect chopped fruits
        var choppedFruits: [String] = []
        for await choppedFruit in group {
            choppedFruits.append(choppedFruit)
        }
        
        return choppedFruits
    }
}

class FoodProcessor {
    static func chopFruit(fruit: String, progress: consuming BasicProgress?) async -> String {
        let progressReporter = progress?.reporter(totalCount: 1)
        ... // expensive async work here
        progressReporter?.complete(count: 1) // This becomes a no-op if the Task is cancelled
        return "Chopped \(fruit)"
    }
}
```

### Advantages of using `ProgresssReporter.Progress` as Currency Type

The advantages of `ProgressReporter` mainly derive from the use of `ProgressReporter.Progress` as a currency to create descendants of `ProgresssReporter`, and the recommended ways to use `ProgressReporter.Progress` are as follows: 

1. Pass `ProgressReporter.Progress` instead of `ProgressReporter` as a parameter to methods that report progress.

`ProgressReporter.Progress` should be used as the currency to be passed into progress-reporting methods, within which a child `ProgressReporter` instance that constitutes a portion of its parent's total units is created via a call to `reporter(totalCount:)`, as follows: 

```swift
func testCorrectlyReportToSubprogressAfterInstantiatingReporter() async {
    let overall = BasicProgressReporter(totalCount: 2)
    await subTask(progress: overall.assign(count: 1))
}

func subTask(progress: consuming BasicProgress?) async {
    let count = 10
    let progressReporter = progress?.reporter(totalCount: count) // returns an instance of ProgressReporter that can be used to report subprogress
    for _ in 1...count {
        progressReporter?.complete(count: 1) // reports progress as usual
    }
}
```

While developers may accidentally make the mistake of trying to report progress to a passed-in `ProgressReporter.Progress`, the fact that it does not have the same properties as an actual `ProgressReporter` means the compiler can inform developers when they are using either `ProgressReporter` or `ProgressReporter.Progress` wrongly. The only way for developers to kickstart actual progress reporting with `ProgressReporter.Progress` is by calling the `reporter(totalCount:)` to create a `ProgressReporter`, then subsequently call `complete(count:)` on `ProgressReporter`.

Each time before progress reporting happens, there needs to be a call to `reporter(totalCount:)`, which returns a `ProgressReporter` instance, before calling `complete(count:)` on the returned `ProgressReporter`. 

The following faulty example shows how reporting progress directly to `ProgressReporter.Progress` without initializing it will be cause a compiler error. Developers will always need to instantiate a `ProgressReporter` from `ProgresReporter<Properties>.Progress` before reporting progress.  

```swift 
func testIncorrectlyReportToSubprogressWithoutInstantiatingReporter() async {
    let overall = BasicProgressReporter(totalCount: 2)
    await subTask(progress: overall.assign(count: 1))
}

func subTask(progress: consuming BasicProgress?) async {
    // COMPILER ERROR: Value of type 'BasicProgress' (aka 'ProgressReporter<BasicProgressProperties>.Progress') has no member 'complete'
    progress?.complete(count: 1)
}
```

2. Consume each `ProgressReporter.Progress` only once, and if not consumed, its parent `ProgressReporter` behaves as if none of its units were ever allocated to create `ProgressReporter.Progress`. 

Developers should create only one `ProgressReporter.Progress` for a corresponding to-be-instantiated `ProgressReporter` instance, as follows: 

```swift 
func testCorrectlyConsumingSubprogress() {
    let overall = BasicProgressReporter(totalCount: 2)
    
    let progressOne = overall.assign(count: 1) // create one ProgressReporter.Progress
    let reporterOne = progressOne.reporter(totalCount: 10) // initialize ProgressReporter instance with 10 units
    
    let progressTwo = overall.assign(count: 1) //create one ProgressReporter.Progress
    let reporterTwo = progressTwo.reporter(totalCount: 8) // initialize ProgressReporter instance with 8 units 
}
```

It is impossible for developers to accidentally consume `ProgressReporter.Progress` more than once, because even if developers accidentally **type** out an expression to consume an already-consumed `ProgressReporter.Progress`, their code won't compile at all. 

The `reporter(totalCount:)` method, which **consumes** the `ProgressReporter.Progress`, can only be called once on each `ProgressReporter.Progress` instance. If there are more than one attempts to call `reporter(totalCount:)` on the same instance of `ProgressReporter.Progress`, the code will not compile due to the `~Copyable` nature of `ProgressReporter.Progress`. 

```swift 
func testIncorrectlyConsumingSubprogress() {
    let overall = BasicProgressReporter(totalCount: 2)
    
    let progressOne = overall.assign(count: 1) // create one BasicProgress
    let reporterOne = progressOne.reporter(totalCount: 10) // initialize ProgressReporter instance with 10 units 

    // COMPILER ERROR: 'progressOne' consumed more than once
    let reporterTwo = progressOne.reporter(totalCount: 8) // initialize ProgressReporter instance with 8 units using same Progress 
}
```

### Interoperability with Foundation's `Progress` 

In both cases below, the propagation of progress of subparts to a root progress should work the same ways Foundation's `Progress` and `ProgressReporter` work.

Consider two progress reporting methods, one which utilizes Foundation's `Progress`, and another using `ProgressReporter`: 

```swift 
// Framework code: Function reporting progress with Foundation's `Progress`
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
func doSomethingWithReporter(progress: consuming BasicProgress?) async -> Int {
    let reporter = progress?.reporter(totalCount: 2)
    //do something
    reporter?.complete(count: 1)
    //do something
    reporter?.complete(count: 1)
}
```

In the case in which we need to receive a `Progress` instance and add it as a child to a `ProgressReporter` parent, we can use the interop method `assign(count: to:)`. 

The choice of naming the interop method as `assign(count: to:)` is to keep the syntax consistent with the method used to add a `ProgressReporter` instance to the progress tree, `assign(count:)`. An example of how these can be used to compose a `ProgressReporter` tree with a top-level `ProgressReporter` is as follows:

```swift 
// Developer code
func testProgressReporterParentProgressChildInterop() async {
    let overall = BasicProgressReporter(totalCount: 2) // Top-level `ProgressReporter`
    
    // Assigning 1 unit of overall's `totalCount` to `ProgressReporter.Progress`
    let progressOne = overall.assign(count: 1)
    // Passing `ProgressReporter.Progress` to method reporting progress
    let result = await doSomethingWithReporter(progress: progressOne)
    
    
    // Getting a Foundation's `Progress` from method reporting progress
    let progressTwo = doSomethingWithProgress() 
    // Assigning 1 unit of overall's `totalCount` to Foundation's `Progress` 
    overall.assign(count: 1, to: progressTwo) 
}
```

The reverse case, in which a framework needs to receive a `ProgressReporter` instance as a child from a top-level `Progress`, can also be done. The interop method `makeChild(withPendingUnitCount: kind:)` added to `Progress` will support the explicit composition of a progress tree. 

The choice of naming the interop method as `makeChild(withPendingUnitCount: kind:)` is to keep the syntax consistent with the method used to add a `Foundation.Progress` instance as a child, `addChild(_: withPendingUnitCount:)`. An example of how this can be used to compose a `Foundation.Progress` tree with a top-level `Foundation.Progress` is as follows: 

```swift
// Developer code 
func testProgressParentProgressReporterChildInterop() {
    let overall = Progress(totalUnitCount: 2)  // Top-level Foundation's `Progress`
    
    // Getting a Foundation's `Progress` from method reporting progress
    let progressOne = doSomethingWithProgress() 
    // Add Foundation's `Progress` as a child which takes up 1 unit of overall's `totalUnitCount`
    overall.addChild(progressOne, withPendingUnitCount: 1)
    
    // Getting a `ProgressReporter.Progress` which takes up 1 unit of overall's `totalUnitCount` 
    let progressTwo = overall.makeChild(withPendingUnitCount: 1, kind: BasicProgressProperties.self)
    // Passing `ProgressReporter.Progress` instance to method reporting progress 
    doSomethingWithReporter(progress: progressTwo)
}
```

## Detailed design

### `ProgressProperties`

The `ProgressProperties` protocol allows you to specify additional properties of a `ProgressReporter` instance. You can create conforming types that contains additional properties on top of the required properties and methods, and these properties further customize `ProgressReporter` and provide more information in localized descriptions returned. 

In addition to specifying additional properties, the `ProgressProperties` protocol also allows you to specify `LocalizedDescriptionOptions` as options for localized descriptions of a `ProgressReporter` provided to observers. 

```swift 
/// `ProgressProperties` is a protocol that defines the requirement for any type of `ProgressReporter<Properties: ProgressProperties>`.
@available(FoundationPreview 6.2, *)
public protocol ProgressProperties : Hashable, Sendable {

    /// Returns a new instance of Self which represents the aggregation of an array of Self.
    ///
    /// Default implementation returns Self as it assumes that there are no children.
    /// - Parameter children: An array of Self to be aggregated.
    /// - Returns: An instance of Self.
    func reduce(children: [Self]) -> Self

    /// A struct containing options for specifying localized description.
    associatedtype LocalizedDescriptionOptions : Hashable, Equatable

    /// Returns a `LocalizedStringResource` for a `ProgressReporter` instance based on `LocalizedDescriptionOptions` specified.
    /// - Parameters:
    ///   - progress: `ProgressReporter` instance to generate localized description for.
    ///   - options: A set of `LocalizedDescriptionOptions` to include in localized description.
    /// - Returns: A  `LocalizedStringResource`.
    func localizedDescription(_ progress: ProgressReporter<Self>, _ options: Set<LocalizedDescriptionOptions>) -> LocalizedStringResource
}
```

There are two implemented conforming types of `ProgressProperties`, namely: 
1. `BasicProgressProperties`: No additional properties
2. `FileProgressProperties`: Additional properties for progress on file-related operations 

#### `BasicProgressProperties`

```swift 
/// A basic implementation of ProgressProperties that contains no additional properties.
@available(FoundationPreview 6.2, *)
public struct BasicProgressProperties : ProgressProperties {

    /// Initializes an instance of `BasicProgressProperties`.
    public init()
    
    /// Returns `self`. This is because there are no properties in `BasicProgressProperties`.
    /// - Parameter children: An array of children of the same `Type`.
    /// - Returns: `self`
    public func reduce(children: [Self]) -> Self

    /// A struct containing all options to choose in specifying how localized description should be generated.
    public struct LocalizedDescriptionOptions: Sendable, Hashable, Equatable {
        
        /// Option to include formatted `fractionCompleted` in localized description.
        /// Example: 20% completed.
        /// - Parameter style: A `FloatingPointFormatStyle<Double>.Percent` used to format `fractionCompleted`.
        /// - Returns: A `LocalizedStringResource` for formatted `fractionCompleted`.
        public static func fractionCompleted(format style: FloatingPointFormatStyle<Double>.Percent = FloatingPointFormatStyle<Double>.Percent()) -> LocalizedDescriptionOptions
        
        /// Option to include formatted `completedCount` / `totalCount` in localized description.
        /// Example: 5 of 10
        /// - Parameter style: An `IntegerFormatStyle<Int>` instance used to format `completedCount` and `totalCount`.
        /// - Returns: A `LocalizedStringResource` for formatted `completedCount` / `totalCount`.
        public static func count(format style: IntegerFormatStyle<Int> = IntegerFormatStyle<Int>()) -> LocalizedDescriptionOptions
    }

    /// Returns a `LocalizedStringResource` based on options provided.
    ///
    /// Examples of localized description that can be generated include:
    /// 20% completed
    /// 2 of 10
    /// 2 of 10 - 20% completed
    ///
    /// - Parameters:
    ///   - progress: `ProgressReporter` instance to generate localized description for.
    ///   - options: A set of `LocalizedDescriptionOptions` to specify information to be included in localized description.
    /// - Returns: A `LocalizedStringResource`.
    public func localizedDescription(_ progress: ProgressReporter<BasicProgressProperties>, _ options: Set<LocalizedDescriptionOptions>) -> LocalizedStringResource
}
```

#### `FileProgressProperties`

```swift
/// A custom `ProgressProperties` to incorporate additional properties such as `totalFileCount` to
/// ProgressReporter, which itself tracks only general properties such as `totalCount`.
@available(FoundationPreview 6.2, *)
public struct FileProgressProperties : ProgressProperties {

    /// Initializes an instance of `FileProgressProperties` with all fields as `nil` or defaults.
    public init()
    
    /// Initializes an instance of `FileProgressProperties`.
    /// - Parameters:
    ///   - totalFileCount: Total number of files.
    ///   - totalByteCount: Total number of bytes.
    ///   - completedFileCount: Completed number of files.
    ///   - completedByteCount: Completed number of bytes.
    ///   - throughput: Throughput in bytes per second.
    ///   - estimatedTimeRemaining: A `Duration` representing amount of time remaining to completion. 
    public init(totalFileCount: Int?, totalByteCount: UInt64?, completedFileCount: Int = 0, completedByteCount: UInt64 = 0, throughput: UInt64? = nil, estimatedTimeRemaining: Duration? = nil)

    /// An Int representing total number of files.
    public var totalFileCount: Int?

    /// An Int representing completed number of files.
    public var completedFileCount: Int

    /// A UInt64 representing total bytes.
    public var totalByteCount: UInt64?

    /// A UInt64 representing completed bytes.
    public var completedByteCount: UInt64

    /// A UInt64 representing throughput in bytes per second.
    public var throughput: UInt64?

    /// A Duration representing amount of time remaining in the processing of files.
    public var estimatedTimeRemaining: Duration?

    /// Returns a new `FileProgressProperties` instance that is a result of aggregating an array of children`FileProgressProperties` instances.
    /// - Parameter children: An Array of `FileProgressProperties` instances to be aggregated into a new `FileProgressProperties` instance.
    /// - Returns: A `FileProgressProperties` instance.
    public func reduce(children: [FileProgressProperties]) -> FileProgressProperties

    /// A struct containing all options to choose in specifying how localized description should be generated.
    public struct LocalizedDescriptionOptions: Sendable, Hashable, Equatable {
        
        /// Option to include formatted `fractionCompleted` in localized description.
        /// Example: 20% completed.
        /// - Parameter style: A `FloatingPointFormatStyle<Double>.Percent` instance used to format `fractionCompleted`.
        /// - Returns: A `LocalizedStringResource` for formatted `fractionCompleted`.
        public static func fractionCompleted(format style: FloatingPointFormatStyle<Double>.Percent = FloatingPointFormatStyle<Double>.Percent()) -> LocalizedDescriptionOptions 
        
        /// Option to include formatted `completedCount` / `totalCount` in localized description.
        /// Example: 5 of 10
        /// - Parameter style: An `IntegerFormatStyle<Int>` instance used to format `completedCount` and `totalCount`.
        /// - Returns: A `LocalizedStringResource` for formatted `completedCount` / `totalCount`.
        public static func count(format style: IntegerFormatStyle<Int> = IntegerFormatStyle<Int>()) -> LocalizedDescriptionOptions

        /// Option to include `completedFileCount` / `totalFileCount` in localized description.
        /// Example: 1 of 5 files
        /// - Parameter style: An `IntegerFormatStyle<Int>` instance used to format `completedFileCount` and `totalFileCount`.
        /// - Returns: A `LocalizedStringResource` for formatted `completedFileCount` / `totalFileCount`.
        public static func fileCount(format style: IntegerFormatStyle<Int> = IntegerFormatStyle<Int>()) -> LocalizedDescriptionOptions
        
        /// Option to include formatted `completedByteCount` / `totalByteCount` in localized description.
        /// Example: Zero kB of 123.5 MB
        /// - Parameter style: A `ByteCountFormatStyle` instance used to format `completedByteCount` and `totalByteCount`.
        /// - Returns: A `LocalizedDescriptionOption` for formatted `completedByteCount` / `totalByteCount`.
        public static func byteCount(format style: ByteCountFormatStyle = ByteCountFormatStyle()) -> LocalizedDescriptionOptions
        
        /// Option to include formatted `throughput` (bytes per second) in localized description.
        /// Example: 10 MB/s
        /// - Parameter style: A `ByteCountFormatStyle` instance used to format `throughput`.
        /// - Returns: A `LocalizedDescriptionOption` for formatted `throughput`.
        public static func throughput(format style: ByteCountFormatStyle = ByteCountFormatStyle()) -> LocalizedDescriptionOptions
        
        /// Option to include `estimatedTimeRemaining` in localized description.
        /// Example: 5 minutes remaining
        /// - Parameter style: `Duration.UnitsFormatStyle` instance used to format `estimatedTimeRemaining`, which is of `Duration` Type.
        /// - Returns: A `LocalizedDescriptionOption` for formatted `estimatedTimeRemaining`.
        public static func estimatedTimeRemaining(format style: Duration.UnitsFormatStyle = Duration.UnitsFormatStyle(allowedUnits: Set(arrayLiteral: .hours, .minutes), width: .wide)) -> LocalizedDescriptionOptions
    }

    /// Returns a custom `LocalizedStringResource` for file-related `ProgressReporter` of `FileProgressProperties` based on the selected `LocalizedDescriptionOptions`.
    /// Examples of localized description that can be generated include:
    /// 20% completed
    /// 5 of 10 files
    /// 2 minutes remaining
    /// 2 of 10 - 20% completed
    ///
    /// - Parameters:
    ///   - progress: `ProgressReporter` instance to generate localized description for.
    ///   - options: A set of `LocalizedDescriptionOptions` to specify information to be included in localized description.
    /// - Returns: A `LocalizedStringResource`.
    public func localizedDescription(_ progress: ProgressReporter<FileProgressProperties>, _ options: Set<LocalizedDescriptionOptions>) -> LocalizedStringResource
}
```

### `ProgressReporter`

`ProgressReporter` serves as a generic interface for users to instantiate progress reporting, which can be characterized further using custom `Properties` created by developers. An instance of `ProgressReporter` can be used to either track progress of a single task, or track progress of a tree of `ProgressReporter` instances.

```swift 
/// Typealiases for ProgressReporter 
public typealias BasicProgressReporter = ProgressReporter<BasicProgressProperties>
public typealias FileProgressReporter = ProgressReporter<FileProgressProperties>

/// Typealiases for ProgressReporter.Progress
public typealias BasicProgress = ProgressReporter<BasicProgressProperties>.Progress
public typealias FileProgress = ProgressReporter<FileProgressProperties>.Progress

/// ProgressReporter is a Sendable class used to report progress in a tree structure.
@available(FoundationPreview 6.2, *)
@Observable public final class ProgressReporter<Properties: ProgressProperties> : Sendable, Hashable, Equatable {

    /// Represents total count of work to be done.
    /// Setting this to `nil` means that `self` is indeterminate,
    /// and developers should later set this value to an `Int` value before using `self` to report progress for `fractionCompleted` to be non-zero.
    public var totalCount: Int? { get set }

    /// Represents completed count of work.
    /// If `self` is indeterminate, returns 0.
    public var completedCount: Int { get }

    /// Represents the fraction completed of the current instance,
    /// taking into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, returns `0.0`.
    public var fractionCompleted: Double { get }

    /// Represents whether work is completed,
    /// returns `true` if completedCount >= totalCount.
    public var isFinished: Bool { get }

    /// Represents whether `totalCount` is initialized to an `Int`,
    /// returns `true` only if `totalCount == nil`.
    public var isIndeterminate: Bool { get }

    /// Access point to additional properties such as `fileTotalCount`
    /// declared within struct of custom type `ProgressProperties`.
    public var properties: Properties { get set }

    /// Initializes `self` with `totalCount` and `properties`.
    /// If `totalCount` is set to `nil`, `self` is indeterminate.
    /// 
    /// - Parameters:
    ///   - totalCount: Total count of work.
    ///   - properties: An instance of`ProgressProperties`.
    public convenience init(totalCount: Int?)

    /// Increases completedCount by `count`.     
    ///
    /// This operation becomes a no-op if Task from which `self` gets created is cancelled.
    /// - Parameter count: Number of units that `completedCount` should be incremented by.
    public func complete(count: Int)

    /// Returns a `ProgressReporter<Properties>.Progress` which can be passed to any method that reports progress.
    ///
    /// Delegates a portion of `self`'s `totalCount` to a to-be-initialized child `ProgressReporter` instance.
    ///
    /// - Parameter count: Count of units delegated to a child instance of `ProgressReporter`
    /// which may be instantiated by calling `reporter(totalCount:)`.
    /// - Parameter kind: `ProgressProperties` of child instance of `ProgressReporter`.
    /// - Returns: A `ProgressReporter<Properties>.Progress` instance.
    public func assign<AssignedProperties>(count: Int, kind: AssignedProperties.Type = AssignedProperties.self) -> ProgressReporter<AssignedProperties>.Progress

    /// Overload for `assign(count: kind:)` for cases where 
    /// `ProgressReporter.Progress` has the same properties of `ProgressReporter`.
    public func assign(count: Int) -> ProgressReporter<Properties>.Progress

    /// Returns a `LocalizedStringResource` for `self`.
    /// 
    /// Examples of localized descriptions that can be generated for `BasicProgressReporter` include:
    /// 5 of 10
    /// 50% completed
    /// 5 of 10 - 50% completed
    /// 
    /// Examples of localized descriptions that can be generated for `FileProgressReporter` include:
    /// 2 of 10 files
    /// Zero kB of 123.5 MB
    /// 2 minutes remaining
    /// 
    /// - Parameter options: A set of `LocalizedDescriptionOptions` to include in localized description. 
    /// - Returns: A `LocalizedStringResource` based on `options`.
    public func localizedDescription(including options: Set<Properties.LocalizedDescriptionOptions>) -> LocalizedStringResource
}

@available(FoundationPreview 6.2, *)
extension ProgressReporter where Properties == BasicProgressProperties {
    
    /// Initializes `self` with `totalCount` and `properties`.
    /// If `totalCount` is set to `nil`, `self` is indeterminate.
    ///
    /// - Parameters:
    ///   - totalCount: Total count of work.
    ///   - properties: An instance of `BasicProgressProperties`.
    public convenience init(totalCount: Int?, properties: BasicProgressProperties = BasicProgressProperties())
}

@available(FoundationPreview 6.2, *)
extension ProgressReporter where Properties == FileProgressProperties {
    
    /// Initializes `self` with `totalCount` and `properties`.
    /// If `totalCount` is set to `nil`, `self` is indeterminate.
    ///
    /// - Parameters:
    ///   - totalCount: Total count of work.
    ///   - properties: An instance of `FileProgressProperties`.
    public convenience init(totalCount: Int?, properties: FileProgressProperties = FileProgressProperties())
}
```

### `ProgressReporter.Progress`

An instance of `ProgressReporter.Progress` is returned from a call to `ProgressReporter`'s `assign(count: kind:)`. `ProgressReporter.Progress` acts as an intermediary instance that you pass into functions that report progress. Additionally, callers should convert `ProgressReporter.Progress` to `ProgressReporter` before starting to report progress with it by calling `reporter(totalCount:)`. 

```swift 
@available(FoundationPreview 6.2, *)
extension ProgressReporter {

    /// ProgressReporter.Progress is a nested ~Copyable struct used to establish parent-child relationship between two instances of ProgressReporter.
    ///
    /// ProgressReporter.Progress is returned from a call to `assign(count:)` by a parent ProgressReporter.
    /// A child ProgressReporter is then returned by calling`reporter(totalCount:)` on a ProgressReporter.Progress.
    public struct Progress : ~Copyable, Sendable {

        /// Instantiates a ProgressReporter which is a child to the parent from which `self` is returned.
        /// - Parameters:
        ///   - totalCount: Total count of returned child `ProgressReporter` instance.
        ///   - properties: An instance of conforming type of`ProgressProperties`.
        /// - Returns: A `ProgressReporter<Properties>` instance.
        public consuming func reporter(totalCount: Int?, properties: Properties) -> ProgressReporter<Properties>
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressReporter.Progress where Properties == BasicProgressProperties {

    /// Instantiates a ProgressReporter which is a child to the parent from which `self` is returned.
    /// - Parameters:
    ///   - totalCount: Total count of returned child `ProgressReporter` instance.
    ///   - properties: An instance of `BasicProgressProperties`.
    /// - Returns: A `ProgressReporter<BasicProgressProperties>` instance.
    public consuming func reporter(totalCount: Int?, properties: BasicProgressProperties = BasicProgressProperties()) -> ProgressReporter<Properties> 
}

@available(FoundationPreview 6.2, *)
extension ProgressReporter.Progress where Properties == FileProgressProperties {

    /// Instantiates a ProgressReporter which is a child to the parent from which `self` is returned.
    /// - Parameters:
    ///   - totalCount: Total count of returned child `ProgressReporter` instance.
    ///   - properties: An instance of `FileProgressProperties`.
    /// - Returns: A `ProgressReporter<FileProgressProperties>` instance.
    public consuming func reporter(totalCount: Int?, properties: FileProgressProperties = FileProgressProperties()) -> ProgressReporter<Properties>
}
```

### Methods for Interoperability with Foundation's `Progress` 

To allow frameworks which may have dependencies on the pre-existing progress-reporting protocol to adopt this new progress-reporting protocol, either as a recipient of a child `Progress` instance that needs to be added to its `ProgressReporter` tree, or as a provider of `ProgressReporter` that may later be added to another framework's `Progress` tree, there needs to be additional support for ensuring that progress trees can be composed with in two cases: 
1. A `ProgressReporter` instance has to parent a `Progress` child
2. A `Progress` instance has to parent a `ProgressReporter` child 

#### ProgressReporter (Parent) - Progress (Child)

To add an instance of `Progress` as a child to an instance of `ProgressReporter`, we pass an `Int` for the portion of `ProgressReporter`'s `totalCount` `Progress` should take up and a `Progress` instance to `assign(count: to:)`. The `ProgressReporter` instance will track the `Progress` instance just like any of its `ProgressReporter` children.

```swift 
@available(FoundationPreview 6.2, *)
extension ProgressReporter {
    // Adds a Foundation's `Progress` instance as a child which constitutes a certain `count` of `self`'s `totalCount`.
    /// - Parameters:
    ///   - count: Number of units delegated from `self`'s `totalCount`.
    ///   - progress: `Progress` which receives the delegated `count`.
    public func assign(count: Int, to progress: Foundation.Progress)
}
```

#### Progress (Parent) - ProgressReporter (Child) 

To add an instance of `ProgressReporter` as a child to an instance of Foundation's `Progress`, the `Progress` instance calls `makeChild(count:kind:)` to get a `ProgressReporter.Progress` instance that can be passed as a parameter to a function that reports progress. The `Progress` instance will track the `ProgressReporter` instance as a child, just like any of its `Progress` children. 

```swift 
@available(FoundationPreview 6.2, *)
extension Progress {
    /// Returns a ProgressReporter.Progress which can be passed to any method that reports progress
    /// and can be initialized into a child `ProgressReporter` to the `self`.
    ///
    /// Delegates a portion of totalUnitCount to a future child `ProgressReporter` instance.
    ///
    /// - Parameter count: Number of units delegated to a child instance of `ProgressReporter`
    /// which may be instantiated by `ProgressReporter.Progress` later when `reporter(totalCount:)` is called.
    /// - Returns: A `ProgressReporter<Properties>.Progress` instance.
    public func makeChild<Kind>(withPendingUnitCount count: Int, kind: Kind.Type = Kind.self) -> ProgressReporter<Kind>.Progress
}
```

## Impact on existing code

There should be no impact on existing code, as this is an additive change. 

However, this new progress reporting API, `ProgressReporter`, which is compatible with Swift's async/await style concurrency, will be favored over the existing `Progress` API going forward. Depending on how widespread the adoption of `ProgressReporter` is, we may consider deprecating the existing `Progress` API. 

## Future Directions 

### Additional Overloads to APIs within UI Frameworks 
To enable the usage of `ProgressReporter` for app development, we can add overloads to APIs within UI frameworks that has previously worked with `Progress`, such as `ProgressView` in SwiftUI. Adding support to existing progress-related APIs within UI Frameworks will enable adoption of `ProgressReporter` for app developers who wish to do extensive progress reporting and show progress on the User Interface using `ProgressReporter`. 

### Distributed `ProgressReporter`
To enable inter-process progress reporting, we would like to introduce distributed `ProgressReporter` in the future, which would functionally be similar to how Foundation's `Progress` mechanism for reporting progress across processes.

## Alternatives considered

### Alternative Names
As Foundation's `Progress` already exists, we had to come up with a name other than `Progress` for this API, but one that still conveys the progress-reporting functionality of this API. Some of the names we have considered are as follows: 

1. Alternative to `ProgressReporter` 
    - `AsyncProgress`  

We decided to proceed with the name `ProgressReporter` because prefixing an API with the term `Async` may be confusing for developers, as there is a precedent of APIs doing so, such as `AsyncSequence` adding asynchronicity to `Sequence`, whereas this is a different case for `ProgressReporter` vs `Progress`.  
    
2. Alternative to `ProgressReporter.Progress` 
    - `ProgressReporter.Link`
    - `ProgressReporter.Child` 
    - `ProgressReporter.Token`  
    
While the names `Link`, `Child`, and `Token` may appeal to the fact that this is a type that is separate from the `ProgressReporter` itself and should only be used as a function parameter and to be consumed immediately to kickstart progress reporting, it is ambiguous because developers may not immedidately figure out its function from just the name itself. `Progress` is an intuitive name because developers will instinctively think of the term `Progress` when they want to adopt `ProgressReporting`. 

3. Alternative to `ProgressProperties` protocol 
    - `ProgressKind`  

While the name `ProgressKind` conveys the message that this is a protocol that developers should conform to when they want to create a different kind of `ProgressReporter`, the protocol mainly functions as a blueprint for developers to add additional properties to the existing properties such as `totalCount` and `completedCount` within `ProgressReporter`, so `ProgressProperties` reads more appropriately here. 

### Introduce `ProgressReporter` to Swift standard library
In consideration for making `ProgressReporter` a lightweight API for server-side developers to use without importing the entire `Foundation` framework, we considered either introducing `ProgressReporter` in a standalone module, or including `ProgressReporter` in existing Swift standard library modules such as `Observation` or `Concurrency`. However, given the fact that `ProgressReporter` has dependencies in `Observation` and `Concurrency` modules, and that the goal is to eventually support progress reporting over XPC connections, `Foundation` framework is the most ideal place to host the `ProgressReporter` as it is the central framework for APIs that provide core functionalities when these functionalities are not provided by Swift standard library and its modules.

### Implement `ProgressReporter` as an actor
We considered implementing `ProgressReporter` as we want to maintain this API as a reference type that is safe to use in concurrent environments. However, if `ProgressReporter` were to be implemented, `ProgressReporter` will not be able to conform to `Observable` because actor-based keypaths do not exist as of now. Ensuring that `ProgressReporter` is `Observable` is important to us, as we want to ensure that `ProgressReporter` works well with UI components in SwiftUI. 

### Implement `ProgressReporter` as a protocol
In consideration of making the surface of the API simpler without the use of generics, we considered implementing `ProgressReporter` as a protocol, and provide implementations for specialized `ProgressReporter` classes that conform to the protocol, namely `BasicProgress`(`ProgressReporter` for progress reporting with only simple `count`) and `FileProgress` (`ProgressReporter` for progress reporting with file-related additional properties such as `totalFileCount`). This had the benefit of developers having to initialize a `ProgressReporter` instance with `BasicProgress(totalCount: 10)` instead of `ProgressReporter<BasicProgressProperties>(totalCount: 10)`. 

However, one of the downside of this is that every time a developer wants to create a `ProgressReporter` that contains additional properties that are tailored to their use case, they would have to write an entire class that conforms to the `ProgressReporter` protocol from scratch, including the calculations of `fractionCompleted` for `ProgressReporter` trees. Additionally, the `~Copyable` struct nested within the `ProgressReporter` class that should be used as function parameter passed to functions that report progress will have to be included in the `ProgressReporter` protocol as an `associatedtype` that is `~Copyable`. However, the Swift compiler currently cannot suppress 'Copyable' requirement of an associated type and developers will need to consciously work around this. These create a lot of overload for developers wishing to report progress with additional metadata beyond what we provide in `BasicProgress` and `FileProgress` in this case. 

We decided to proceed with implementing `ProgressReporter` as a generic class to lessen the overhead for developers in customizing metadata for `ProgressReporter`, and at the same time introduce typealiases that simplify the API surface as follows: 
```swift 
public typealias BasicProgressReporter = ProgressReporter<BasicProgressProperties>
public typealias FileProgressReporter = ProgressReporter<FileProgressProperties>
public typealias FileProgress = ProgressReporter<FileProgressProperties>.Progress
public typealias BasicProgress = ProgressReporter<BasicProgressProperties>.Progress
``` 

### Introduce an `Observable` adapter for `ProgressReporter`
We thought about introducing a clearer separation of responsibility between the reporting and observing of a `ProgressReporter`, because progress reporting is often done by the framework, and the caller of a certain method of a framework would merely observe the `ProgressReporter` within the framework. This will deter observers from accidentally mutating values of a framework's `ProgressReporter`. 

However, this means that `ProgressReporter` needs to be passed into the `Observable` adapter to make an instance `ObservableProgressReporter`, which can then be passed into `ProgressView()` later. We decided that this is too much overhead for developers to use for the benefit of avoiding observers from mutating values of `ProgressReporter`. 

### Introduce Support for Cancellation, Pausing, and Resuming of `ProgressReporter`
Foundation's `Progress` provides support for cancelling, pausing and resuming an ongoing operation tracked by an instance of `Progress`, and propagates these actions down to all of its children. We decided to not introduce support for this behavior as there is support in cancelling a `Task` via `Task.cancel()` in Swift structured concurrency. The absence of support for cancellation, pausing and resuming in `ProgressReporter` helps to clarify the scope of responsibility of this API, which is to report progress, instead of owning a task and performing actions on it.

### Move `totalCount` and `completedCount` properties to `ProgressProperties` protocol
We considered moving the `totalCount` and `completedCount` properties from `ProgressReporter` to `ProgressProperties` to allow developers the flexibility to set the Type of `totalCount` and `completedCount`. This would allow developers to set the Type to `Int`, `UInt128`, `Int64`, etc. While this flexibility may be desirable for allowing developers to determine what Type they need, most developers may not be concerned with the Type, and some Types may not pair well with the calculations that need be done within `ProgressReporter`. This flexibility may also lead to developer errors that cannot be handled by `ProgressReporter` such as having negative integers in `totalCount`, or assigning more than available units to create `ProgressReporter.Progress`. Having `totalCount` and `completedCount` as `Int` in `ProgressReporter` reduces programming errors and simplifies the process of using `ProgressReporter` to report progress.

### Introduce `totalCount` and `completedCount` properties as `UInt64`
We considered using `UInt64` as the type for `totalCount` and `completedCount` to support the case where developers use `totalCount` and `completedCount` to track downloads of larger files on 32-bit platforms byte-by-byte. However, developers are not encouraged to update progress byte-by-byte, and should instead set the counts to the granularity at which they want progress to be visibly updated. For instance, instead of updating the download progress of a 10,000 bytes file in a byte-by-byte fashion, developers can instead update the count by 1 for every 1,000 bytes that has been downloaded. In this case, developers set the `totalCount` to 10 instead of 10,000. To account for cases in which developers may want to report the current number of bytes downloaded, we added `totalByteCount` and `completedByteCount` to `FileProgressProperties`, which developers can set and display within `localizedDescription`.

### Store Foundation's `Progress` in TaskLocal Storage
This would allow a `Progress` object to be stored in Swift `TaskLocal` storage. This allows the implicit model of building a progress tree to be used from Swift Concurrency asynchronous contexts. In this solution, getting the current `Progress` and adding a child `Progress` is done by first reading from TaskLocal storage when called from a Swift Concurrency context. This method was found to be not preferable as we would like to encourage the usage of the explicit model of Progress Reporting, in which we do not depend on an implicit TaskLocal storage and have methods that report progress to explicitly accepts a `Progress` object as a parameter. 

### Add Convenience Method to Foundation's `Progress` for Easier Instantiation of Child Progress
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

## Acknowledgements 

Thanks to [Tony Parker](https://github.com/parkera) and [Tina Liu](https://github.com/itingliu) for constant feedback and guidance throughout to help shape this API and proposal. I would also like to thank [Jeremy Schonfeld](https://github.com/jmschonfeld), [Cassie Jones](https://github.com/porglezomp), [Konrad Malawski](https://github.com/ktoso), [Philippe Hausler](https://github.com/phausler), Julia Vashchenko for valuable feedback on this proposal and its previous versions. 
