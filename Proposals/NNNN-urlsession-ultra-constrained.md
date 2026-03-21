# URLSession Ultra-Constrained Network Access API

* Proposal: [SF-NNNN](NNNN-urlsession-ultra-constrained.md)
* Author: [Travis Langston](https://github.com/travarin)
* Review Manager: TBD
* Status: **Awaiting implementation**
* Implementation: Pending
* Review: ([pitch](https://forums.swift.org/t/pitch-ultra-constrained-networking-in-urlsession-on-darwin/82345/1))

## Introduction

Apps on Darwin are able to check if a network path uses an interface that is considered ultra-constrained by the system through the `isUltraConstrained` property on NWPath, and can then adjust whether a particular connection is allowed to use those interfaces through the `allowUltraConstrainedPaths` property on the `NWParameters`. In this proposal, we're introducing an API to allow apps that use URLSession on Darwin to also have this same capability of checking whether using ultra-constrained interfaces is currently allowed and specifying whether a particular session or request are allowed to use them. 

## Proposed solution

The proposed solution involves three changes:

- Add a `allowsUltraConstrainedNetworkAccess` property on `URLSessionConfiguration`, to parallel existing properties like `allowsExpensiveNetworkAccess` and `allowsConstrainedNetworkAccess`. 

- Add a `allowsUltraConstrainedNetworkAccess` property on `URLRequest`, to parallel existing properties like `allowsExpensiveNetworkAccess` and `allowsConstrainedNetworkAccess`. 

- Add a new enum value `NSURLErrorNetworkUnavailableReasonUltraConstrained` for `NSURLErrorNetworkUnavailableReason`, to parallel existing values like `NSURLErrorNetworkUnavailableReasonExpensive` and `NSURLErrorNetworkUnavailableReasonConstrained`.

These flags are not available on non-Darwin platforms at this moment. 

## Example usage

The following example allows an application to explicitly allow the task that follows to go over ultra-constrained interfaces. 

```swift
let configuration = URLSessionConfiguration.default
configuration.allowsUltraConstrainedNetworkAccess = true

let session = URLSession(configuration: configuration)
let (data, response) = try await session.data(from: url)
```

Explicitly opting out a particular request, preventing it from being made over ultra-constrained interfaces.

```swift
var request = URLRequest(url: URL(string: "https://www.example.com")!)
request.allowsUltraConstrainedNetworkAccess = false
let task = session.dataTask(with: request) { data, response, error in
    // Handle response
}
task.resume()
```

## Detailed design

We add a new property to `URLSessionConfiguration` that lets a caller control whether URLSession is allowed to use ultra-constrained network paths.

```swift
open class URLSessionConfiguration : NSObject, NSCopying, @unchecked Sendable {

...
    @available(*, unavailable, message: "Not available on non-Darwin platforms")
    open var allowsUltraConstrainedNetworkAccess : Bool
...

}
```

We also add a new property to `URLRequest` that lets a caller set if that particular request is allowed to use ultra-constrained network paths. Explicitly setting the property on the `URLRequest` used to create the `URLSessionTask` would override the `URLSessionConfiguration` setting.

```swift
public struct URLRequest {

...
    @available(*, unavailable, message: "Not available on non-Darwin platforms")
    open var allowsUltraConstrainedNetworkAccess : Bool
...

}
```

Finally we add a new enum value to NetworkUnavailableReason which can be returned in the userInfo dictionary with the key `NSURLErrorNetworkUnavailableReasonKey` to indicate connectivity was unavailable because the only routes available were ultra constrained and this did not meet the constraints set on the task. 

```swift
/// Reasons used by URLError to indicate that a URLSessionTask failed because of unsatisfiable network constraints.
public enum NetworkUnavailableReason : Int, Sendable {
    @available(*, unavailable, message: "Not available on non-Darwin platforms")
    case ultraConstrained
}
```

## Source compatibility

No impact. 

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Alternatives considered

The biggest question here is the name of the property. "Ultra-constrained" is the name we have in the Network.framework API, and this proposal adds a corresponding API to URLSession. 
