# Concurrency-Safe Notifications

* Proposal: SF-NNNN
* Author(s): [Philippe Hausler](https://github.com/phausler), [Christopher Thielen](https://github.com/cthielen)
* Review Manager: TBD
* Status: **Draft**

## Revision history

* **v1** Initial version

## Introduction

The `NotificationCenter` API provides the ability to decouple code through a pattern of "posting" notifications and "observing" them. It is highly-integrated throughout frameworks on macOS, iOS, and other Darwin-based systems.

Posters send notifications identified by `Notification.Name`, and optionally include a payload in the form of `object` and `userInfo` fields.

Observers receive notifications by registering code blocks or providing closures for a given identifier. They may also provide an optional `OperationQueue` for the observer to execute on.

This proposal aims to improve the safety of `NotificationCenter` in Swift by providing explicit support for Swift Concurrency and by adopting stronger typing for notifications.

## Motivation

Idiomatic Swift code uses a number of features that help maintain program correctness and catch errors at compile-time.

For `NotificationCenter`:

 * **Compile-time concurrency checking:** Notifications today rely on an implicit contract that an observer's code block will run on the same thread as the poster, requiring the client to look up concurrency contracts in documentation, or defensively apply concurrency mechanisms which may or may not lead to issues. Notifications do allow the observer to specify an `OperationQueue` to execute on, but this concurrency model does not provide compile-time checking and may not be desirable to clients using Swift Concurrency.
 * **Stronger types:** Notifications do not use very strong types, neither in the notification identifier nor the notification's payload. Stronger typing can help the compiler validate that the expected notification is being used and avoid the possibility of spelling mistakes that come with using strings as identifiers. Stronger typing can also reduce the number of times a client needs to cast an object from one type to another when working with notification payloads.

Well-written Swift code strongly prefers being explicit about concurrency isolation and types to help the compiler ensure program safety and correctness.

## Proposed solution and example

We propose a new protocol, `NotificationCenter.Message`, which allows the creation of types that can be posted and observed using `NotificationCenter`. `NotificationCenter.Message` provides support for isolation in Swift Concurrency and is designed to interoperate with the existing `Notification` type for easy adoption.

`NotificationCenter.Message` is created by specifying a name of type `Notification.Name`:

```swift
struct EventDidOccur: NotificationCenter.Message {
    static var name: Notification.Name { eventDidOccurNotification }
}
```

Providing a `Notification.Name` enables `NotificationCenter.Message` to interoperate with posters and observers of the existing `Notification` type.

By default, observers of types conforming to `NotificationCenter.Message` will be observed on `MainActor`, and other isolations can be expressed as well:

```swift
struct EventDidOccur: NotificationCenter.Message {
    static var name: Notification.Name { eventDidOccurNotification }
    static var isolation: EventActor { EventActor.shared }
}
```

This information is used by the compiler to ensure isolation:

```swift
NotificationCenter.default.addObserver(EventDidOccur.self) { message, isolation in
    // This is bound to the isolation of EventActor as specified by EventDidOccur
}
```

When a `NotificationCenter.Message` shares its name with an existing `Notification`, its observers will be called when either `NotificationCenter.Message` or `Notification` is posted. To make this behavior transparent to any observers, you can optionally define a `static makeMessage(:Notification)` method to transform the contents of a posted `Notification` into a `NotificationCenter.Message`:

```swift
struct EventDidOccur: NotificationCenter.Message {
    ...
    
    static func makeMessage(_ notification: Notification) -> Self? {
        // Transform notification.userInfo? into stored properties, etc.
        guard let contents = notification.userInfo?["contents"] as? String else {
            return nil
        }
        
        ...
    }
}
```

You can also offer the reverse, posting a `NotificationCenter.Message` and transforming its contents for observers expecting the existing `Notification` type, e.g. observers in Objective-C code:

```swift
struct EventDidOccur: NotificationCenter.Message {
    ...
    
    static func makeNotification(_ message: Self) -> Notification {
        // Transform stored properties into notification.object? and notification.userInfo?
        return Notification(name: Self.name, object: message.someProperty, userInfo: ["payload": message.someOtherProperty])
    }
}
```

Here's an example of adapting the existing [NSWorkspace.willLaunchApplicationNotification](https://developer.apple.com/documentation/appkit/nsworkspace/1528611-willlaunchapplicationnotificatio) `Notification` to use `NotificationCenter.Message`:

```swift
extension NSWorkspace {
    // Bound to MainActor by default
    public struct WillLaunchApplication: NotificationCenter.Message {
        public static var name: Notification.Name { NSWorkspace.willLaunchApplicationNotification }
        public var workspace: NSWorkspace
        public var runningApplication: NSRunningApplication

        init(workspace: NSWorkspace, runningApplication: NSRunningApplication) {
            self.workspace = workspace
            self.runningApplication = runningApplication
        }

        static func makeMessage(_ notification: Notification) -> Self? {
            guard let workspace = notification.object as? NSWorkspace,
                  let runningApplication = notification.userInfo?["applicationUserInfoKey"] as? NSRunningApplication
            else { return nil }
            
            self.init(workspace: workspace, runningApplication: runningApplication)
        }
        
        static func makeNotification(_ message: Self) -> Notification {
            return Notification(name: Self.name, object: message.workspace, userInfo: ["applicationUserInfoKey": message.runningApplication])
        }
    }
}
```

This notification could be observed by a client using:

```swift
NotificationCenter.default.addObserver(WillLaunchApplication.self) { message in 
    // Do something with message.runningApplication ...
}
```

And it could be posted using:

```swift
NotificationCenter.default.post(
    WillLaunchApplication(workspace: someWorkspace, runningApplication: someRunningApplication)
)
```

## Detailed design

### The `NotificationCenter.Message` protocol

The new `NotificationCenter.Message` protocol enables the creation of types that can be posted and observed using `NotificationCenter`. These types include isolation information for the compiler, defaulting to `MainActor` if no other isolation is specified:

```swift
@available(FoundationPreview 0.5, *)
extension NotificationCenter {
    public protocol Message<Isolation> {
        associatedtype Isolation: Actor
    
        static var name: Notification.Name { get }
        static var isolation: Isolation { get }
        
        static func makeMessage(_ notification: Notification) -> Self?
        static func makeNotification(_ message: Self) -> Notification
    }
}

@available(FoundationPreview 0.5, *)
extension NotificationCenter.Message where Isolation == MainActor {
    public static var isolation: MainActor { .shared }
}
```

`NotificationCenter.Message` is designed to interoperate with existing uses of `Notification` by sharing `Notification.Name` identifiers. This means an observer expecting `NotificationCenter.Message` will be called when a `Notification` is posted if the `Notification.Name` identifier matches, and vice versa.

For this reason, the protocol specifies the static methods `makeMessage(:Notification)` and `makeNotification(:Self)` to transform the payload between posters and observers of both the `NotificationCenter.Message` and `Notification` types. These methods have default implementations in cases where interoperability with `Notification` is not necessary.

### Observing messages

Observing `NotificationCenter.Message` can be done with new overloads to `addObserver`:

```swift
    @available(FoundationPreview 0.5, *)
    public func addObserver<MessageType: NotificationCenter.Message>(
        _ notification: MessageType.Type,
        observer: @Sendable @escaping (MessageType, isolated MessageType.Isolation) -> Void
    ) -> ObservationToken
```

As well as one specialized for `MainActor`, which no longer requires the `isolated MessageType.Isolation` parameter to capture the isolation:

```swift
    @available(FoundationPreview 0.5, *)
    public func addObserver<MessageType: NotificationCenter.Message>(
        _ notification: MessageType.Type,
        observer: @MainActor @Sendable @escaping (MessageType) -> Void
    ) -> ObservationToken
```

These overloads ensure that the `observer` closure will be called on the isolation specified by the `NotificationCenter.Message`, and enable the compiler to provide the expected isolation diagnostics.

They also return a new `ObservationToken`, which can be used with a new `removeObserver()` method for faster de-registration of observers:

```swift
@available(FoundationPreview 0.5, *)
extension NotificationCenter {
	public struct ObservationToken: Hashable, Sendable
	
	public func removeObserver(_ token: ObservationToken)
}
```

### Posting messages

Like the new `addObserver` overloads, the new `post` overloads allow for both an arbitrary isolation as well as a `MainActor` specialization:

```swift
@available(FoundationPreview 0.5, *)
public func post<MessageType: NotificationCenter.Message>(_ message: MessageType,
                                                          isolation: isolated MessageType.Isolation = MessageType.isolation)

@available(FoundationPreview 0.5, *)
@MainActor
public func post<MessageType: NotificationCenter.Message>(_ message: MessageType) where MessageType.Isolation == MainActor
```

Posting only requires passing an instance of the `NotificationCenter.Message`-conforming type:

```swift
NotificationCenter.default.post(WillLaunchApplication(...))
```

Like the existing `post()` methods, all observers will be called synchronously and serially to ensure existing notification usage patterns like `will` / `did` are executed in order. This is possible because the isolation used to call `post()` will match the isolation defined by `NotificationCenter.Message`, and all observers will then be called from that same isolation.

Unlike the existing `post()`, these methods do not accept the `object` and `userInfo` parameters. Instead, clients should store their payloads in their `NotificationCenter.Message`-conforming types.

```swift
message.payloadVariable = SomeType()

NotificationCenter.default.post(message)
```

### Interoperability with `Notification`

Clients can also migrate information to and from existing `Notification` types using `NotificationCenter.Message.makeMessage(:Notification)` and `NotificationCenter.Message.makeNotification(:Self)`. Implementing these enables the mixing of posters and observers between the `Notification` and `NotificationCenter.Message` types:

```swift
struct EventDidOccur: NotificationCenter.Message {
    var foo: Foo
    ...

    static func makeMessage(_ notification: Notification) -> Self? {
        guard let foo = notification.userInfo["foo"] as? Foo else { return nil }
        return Self(foo: foo)
    }
    
    static func makeNotification(_ message: Self) -> Notification {
        return Notification(name: Self.name, object: message.someProperty, userInfo: ["foo": message.foo])
    }
}
```

These methods do not need to be implemented if all posters and observers are using `NotificationCenter.Message`.

If `Notification` and `NotificationCenter.Message` posters and observers are mixed without implementing these methods, observers for both types will be called but will not receive the associated payloads.

### Isolation from non-Swift Concurrency posters

Observers called via the existing, pre-Swift Concurrency `.post()` methods are either called on the same thread as the poster, or called in an explicitly passed `OperationQueue`.

However, users can still adopt `NotificationCenter.Message` with pre-Swift Concurrency `.post()` calls by providing a `NotificationCenter.Message` with the proper `Notification.Name` value and isolation information. For example, if an Objective-C method calls the `post(name:object:userInfo:)` method on the main thread, `NotificationCenter.Message` can be used to define a message with the same `Notification.Name` and provide the appropriate isolation information, enabling clients observing `NotificationCenter.Message` to access the `object` and `userInfo` parameters of the original `Notification` in a safe manner through `makeMessage(:Notification)`.

The new `addObserver` methods will attempt to check isolation and may halt program execution if isolation expectations are mismatched.

## Impact on existing code

These changes are entirely additive but could impact existing code due to the ability to interoperate between `NotificationCenter.Message` and `Notification`.

Specifically, if an observer for `NotificationCenter.Message` receives a message posted as a `Notification` which violates the isolation contract specified in `NotificationCenter.Message`, the correct fix may be to modify the existing `Notification` `.post()` call to uphold that contract.

## Alternatives considered

### Maintain the use of `object` and `userInfo` instead of posting instances of `NotificationCenter.Message`
We could achieve the goals of adopting Swift Concurrency and providing stronger type information by using a design which more closely aligns with the existing APIs:

```swift
public func post<NotificationType: IsolatedNotification>(_ notification: NotificationType.Type,
                                                         isolation: NotificationType.Isolation = NotificationType.isolation,
                                                         object: Any? = nil,
                                                         userInfo: [AnyHashable : Any]? = nil)
```

While this design works, it encourages the use of the `object` and `userInfo` parameters, which eschew the stronger type information provided by creating specific `NotificationCenter.Message`-conforming types.

### Require `NotificationCenter.Message` to conform to `Sendable`
Conforming `NotificationCenter.Message` to `Sendable` is not necessary due to the `addObserver` and `post` methods enforcing the isolation specified by `NotificationCenter.Message`.

Further, there may be cases where a non-`Sendable` `NotificationCenter.Message` is posted and observed from within the same isolation, which is a valid operation and should not be disallowed.
