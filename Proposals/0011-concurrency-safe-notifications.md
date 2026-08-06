# Concurrency-Safe Notifications

* Proposal: SF-0011
* Author(s): [Philippe Hausler](https://github.com/phausler), [Christopher Thielen](https://github.com/cthielen)
* Review Manager: [Charles Hu](https://github.com/iCharlesHu)
* Status: **Accepted**

## Revision history

* **v1** Initial version
* **v2** Remove `static` from `NotificationCenter.Message.isolation` to better support actor instances
* **v3** Remove generic isolation pattern in favor of dedicated `MainActorMessage` and `AsyncMessage` types. Apply SE-0299-style static member lookups for `addObserver()`. Provide default value for `Message.name`.
* **v4** Add `AsyncSequence` APIs for observing. Expand `Message.Subject` conformance to take either `AnyObject` or `Identifiable` where `Identifiable.ID == ObjectIdentifier`. Document `ObservationToken` automatic de-registration behavior. Drop `with` label on `post()` methods in favor of `subject` for clarity.
* **v5** Remove `Message` base protocol. Remove the `Identifiable`-based overloads.

## Introduction

`NotificationCenter` provides the ability to decouple code through a pattern of "posting" notifications and "observing" them. It is highly-integrated throughout frameworks on macOS, iOS, and other Darwin-based systems.

Posters send notifications identified by `Notification.Name`, and optionally include a payload in the form of `object` and `userInfo` fields.

Observers receive notifications by registering code blocks or providing closures for a given identifier. They may also provide an optional `OperationQueue` for the observer to execute on.

This proposal aims to improve the safety of `NotificationCenter` in Swift by providing explicit support for Swift Concurrency and by adopting stronger typing for notifications.

## Motivation

Idiomatic Swift code uses a number of features that help maintain program correctness and catch errors at compile-time.

For `NotificationCenter`:

 * **Compile-time concurrency checking:** Notifications today rely on an implicit contract that an observer's code block will run on the same thread as the poster, requiring the client to look up concurrency contracts in documentation, or defensively apply concurrency mechanisms which may or may not lead to issues. Notifications do allow the observer to specify an `OperationQueue` to execute on, but this concurrency model does not provide compile-time checking and may not be desirable to clients using Swift Concurrency.
 * **Stronger types:** Notifications do not use very strong types, neither in the notification identifier nor the notification's payload. Stronger typing can help the compiler validate that the expected notification is being used and avoid the possibility of spelling mistakes that come with using strings as identifiers. Stronger typing can also reduce the number of times a client needs to cast an object from one type to another when working with notification payloads.

Well-written Swift code strongly prefers being explicit about concurrency isolation and types to help the compiler ensure program safety and correctness.

## Proposed solution

We propose two new protocols, `NotificationCenter.MainActorMessage` and `NotificationCenter.AsyncMessage`, which allow the creation of strong types that can be posted and observed using `NotificationCenter`, and an optional protocol, `NotificationCenter.MessageIdentifier`, which provides a typed, ergonomic experience when registering observers.

These protocols can be used on top of existing `Notification` declarations, enabling quick adoption.

```swift
// Client-side

// Compiler will type-check that .willLaunchApplication is valid for workspace
let token = center.addObserver(of: workspace, for: .willLaunchApplication) { message in
    // Do something with message properties (e.g. message.application)
    // Bound to MainActor
}

// Framework-side

// Adapting the existing NSWorkspace.willLaunchApplicationNotification notification ...
extension NSWorkspace {
    public struct WillLaunchApplication: NotificationCenter.MainActorMessage {
        // Protocol requirements
        public static var name: Notification.Name { NSWorkspace.willLaunchApplicationNotification }
        typealias Subject = NSWorkspace
        
        // Custom properties
        public var application: NSRunningApplication
    }
}

// Optional SE-0299-style message identifier
extension NotificationCenter.MessageIdentifier
    where Self == NotificationCenter.BaseMessageIdentifier<NSWorkspace.WillLaunchApplication> {
    static var willLaunchApplication: Self { .init() }
}
```

Messages conforming to `MainActorMessage` will bind observers to `MainActor` and deliver messages synchronously from `MainActor`-bound contexts, while messages conforming to `AsyncMessage` are `Sendable`, run observers in an asynchronous context, and are delivered asynchronously.

The optional lookup type, `NotificationCenter.MessageIdentifier`, provides an [SE-0299](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0299-extend-generic-static-member-lookup.md)-style ergonomic experience for finding notification types when registering observers.

The first parameter of `addObserver(of:for:)` accepts both metatypes and instance types. Registering with a metatype enables an observer to receive all messages for the given identifier (equivalent to `object = nil` in the current `NotificationCenter`), while registering with an instance will only deliver messages related to that instance.

Optional bi-directional interoperability with the existing `Notification` type is available by using the `Notification.Name` property and two optional methods, `makeMessage(:Notification)` and `makeNotification(:Self)`:

```swift
// Framework-side

extension NSWorkspace {
    public struct WillLaunchApplication: NotificationCenter.MainActorMessage {
        // This message shares its name with an existing Notification
        public static var name: Notification.Name { NSWorkspace.willLaunchApplicationNotification }
        public typealias Subject = NSWorkspace
        
        public var application: NSRunningApplication

        public static func makeMessage(_ notification: Notification) -> Self? {
            guard
                let application = notification.userInfo?["applicationUserInfoKey"] as? NSRunningApplication
            else {
                return nil
            }
            
            return Self(application: application)
        }
        
        // makeNotification() does not need to translate `object`
        public static func makeNotification(_ message: Self) -> Notification {
            return Notification(name: Self.name,
                                userInfo: ["applicationUserInfoKey": message.application])
        }
    }
}
```

Using these methods, posters and observers of both the `Notification` and `Message`-style type have full, bi-directional interoperability.

## Example usage

This example adapts the existing [NSWorkspace.willLaunchApplicationNotification](https://developer.apple.com/documentation/appkit/nsworkspace/1528611-willlaunchapplicationnotificatio) `Notification` to use `NotificationCenter.MainActorMessage`. It defines the optional `MessageIdentifier` to make registering observers easier, and it defines `makeMessage(:Notification)` and `makeNotification(:Self)` for bi-directional interoperability with existing NotificationCenter posters and observers.

Existing code which vends notifications do not need to alter existing `Notification` declarations, observers, or posts to adopt to this proposal.

```swift
extension NSWorkspace {
    public struct WillLaunchApplication: NotificationCenter.MainActorMessage {
        public static var name: Notification.Name { NSWorkspace.willLaunchApplicationNotification }
        public typealias Subject = NSWorkspace
        
        public var application: NSRunningApplication

        public static func makeMessage(_ notification: Notification) -> Self? {
            guard
                let application = notification.userInfo?["applicationUserInfoKey"] as? NSRunningApplication
            else {
                return nil
            }
            
            return Self(application: application)
        }
        
        public static func makeNotification(_ message: Self) -> Notification {
            return Notification(name: Self.name, userInfo: ["applicationUserInfoKey": message.application])
        }
    }
}

extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NSWorkspace.WillLaunchApplication> {
    static var willLaunchApplication: Self { .init() }
}
```

This notification could be observed by a client using:

```swift
let token = center.addObserver(of: workspace, for: .willLaunchApplication) { message in
    // Do something with message.application
}

// Or, without a specific instance to observe ...

let token = center.addObserver(of: NSWorkspace.self, for: .willLaunchApplication) { message in
    // Do something with message.application
}
```

And it could be posted using:

```swift
NotificationCenter.default.post(
    NSWorkspace.WillLaunchApplication(application: launchedApplication),
    subject: workspace
)
```

## Detailed design

### `NotificationCenter.MainActorMessage` and `NotificationCenter.AsyncMessage`

`NotificationCenter.MainActorMessage` and `NotificationCenter.AsyncMessage` contain similar functionality:

```swift
@available(FoundationPreview 0.5, *)
extension NotificationCenter {
    public protocol MainActorMessage: SendableMetatype {
        associatedtype Subject
        
        static var name: Notification.Name { get }
        
        @MainActor static func makeMessage(_ notification: Notification) -> Self?
        @MainActor static func makeNotification(_ message: Self) -> Notification
    }

    public protocol AsyncMessage: Sendable {
        associatedtype Subject
        
        static var name: Notification.Name { get }
        
        static func makeMessage(_ notification: Notification) -> Self?
        static func makeNotification(_ message: Self) -> Notification
    }
}
```

These two protocols are designed to interoperate with existing uses of `Notification` by sharing `Notification.Name` identifiers. This means an observer expecting a type conforming to either of these protocols will be called when a `Notification` is posted if the `Notification.Name` identifier matches, and vice versa.

The protocol specifies `makeMessage(:Notification)` and `makeNotification(:Self)` to transform the payload between posters and observers of both the `Message`-style and `Notification` types. These methods have default implementations in cases where interoperability with `Notification` is not necessary.

For `Message`-style types that do not need to interoperate with existing `Notification` uses, the `name` property does not need to be specified, and will default to the fully qualified name of the `Message`-style type, e.g. `MyModule.MyMessage`. Note that when using this default, renaming the type or relocating it to another module has a similar effect as changing ABI for any code that relies on a particular spelling. Developers can control this effect by explicitly setting the `name` property if needed.

Each `Message`-style type specifies a specific *subject* variable or metatype to observe, similar to the existing `Notification.object`, e.g. an `NSWindow` instance or the `NSWindow.self` metatype. `Subject` has no conformance requirements in the protocols, but `addObserver()` and `post()` both refine `Subject` to conform to `AnyObject`. This allows for the posting and observing of either objects or metatypes.

### Observing messages

Observing messages can be done with new overloads to `addObserver`. Clients do not need to know whether a message conforms to `MainActorMessage` or `AsyncMessage`.

For `MainActorMessage`:

```swift
@available(FoundationPreview 0.5, *)
extension NotificationCenter {
    // e.g. addObserver(of: workspace, for: .willLaunchApplication) { message in ... }
    public func addObserver<Identifier: MessageIdentifier, Message: MainActorMessage>(
        of subject: Message.Subject,
        for identifier: Identifier,
        using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Identifier.MessageType == Message, Message.Subject: AnyObject
    
    // e.g. addObserver(of: NSWorkspace.self, for: .willLaunchApplication) { message in ... }
    public func addObserver<Identifier: MessageIdentifier, Message: MainActorMessage>(
        of subject: Message.Subject.Type,
        for identifier: Identifier,
        using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Identifier.MessageType == Message

    // e.g. addObserver(for: NSWorkspace.WillLaunchApplication.self) { message in ... }
    public func addObserver<Message: MainActorMessage>(
        of subject: Message.Subject? = nil,
        for messageType: Message.Type,
        using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Message.Subject: AnyObject
}
```

And for `AsyncMessage`:

```swift
@available(FoundationPreview 0.5, *)
extension NotificationCenter {
    public func addObserver<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject,
        for identifier: Identifier,
        using observer: @escaping @Sendable (Message) async -> Void
    ) -> ObservationToken where Identifier.MessageType == Message, Message.Subject: AnyObject

    public func addObserver<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject.Type,
        for identifier: Identifier,
        using observer: @escaping @Sendable (Message) async -> Void
    ) -> ObservationToken where Identifier.MessageType == Message
    
    public func addObserver<Message: AsyncMessage>(
        of subject: Message.Subject? = nil,
        for messageType: Message.Type,
        using observer: @escaping @Sendable (Message) async -> Void
    ) -> ObservationToken where Message.Subject: AnyObject
}
```

Observer closures take a single `Message`-style parameter and do not receive the `subject` parameter passed to `addObserver()` nor `post()`. Not all messages use instances for their subjects, and not all subject instances are `Sendable` though their messages may be. If a `Message`-style type needs the `subject` to be delivered to the observer, it can be added as a property on the message type.

These `addObserver()` methods return a new `ObservationToken`, which can be used with a new `removeObserver()` method for faster de-registration of observers:

```swift
@available(FoundationPreview 0.5, *)
extension NotificationCenter {
	public struct ObservationToken: Hashable, Sendable { ... }
	
	public func removeObserver(_ token: ObservationToken)
}
```

When an `ObservationToken` goes out of scope, the corresponding observer will be removed from its center automatically if it is still registered. This behavior helps prevent memory leaks from tokens which are accidentally dropped by the user.

Messages conforming to `AsyncMessage` can also be observed using a set of `AsyncSequence`-conforming APIs, similar to the existing `notifications(named:object:)` method:

```swift
@available(macOS 16, iOS 19, tvOS 19, watchOS 12, visionOS 3, *)
extension NotificationCenter {
	public func messages<Identifier: MessageIdentifier, Message: AsyncMessage>(
		of subject: Message.Subject,
		for identifier: Identifier,
		bufferSize limit: Int = 10
	) -> some AsyncSequence<Message, Never> where Identifier.MessageType == Message, Message.Subject: AnyObject
	
	public func messages<Identifier: MessageIdentifier, Message: AsyncMessage>(
		of subject: Message.Subject.Type,
		for identifier: Identifier,
		bufferSize limit: Int = 10
	) -> some AsyncSequence<Message, Never> where Identifier.MessageType == Message
	
	public func messages<Message: AsyncMessage>(
		of subject: Message.Subject? = nil,
		for messageType: Message.Type,
		bufferSize limit: Int = 10
	) -> some AsyncSequence<Message, Never> where Message.Subject: AnyObject
}
```

These allow for the familiar `for await in` syntax:

```swift
for await message in center.messages(of: anObject, for: .anAsyncMessage) {
    // ...
}

for await message in center.messages(for: AnAsyncMessage.self) {
    // ...
}

// etc.
```

If the sequence buffer limit is exceeded, the implementation will log to aid in debugging.

### Posting messages

Posting messages can be done with new overloads on the existing `post` method:

```swift
@available(FoundationPreview 0.5, *)
extension NotificationCenter {

    // MainActorMessage post()

    @MainActor
    public func post<Message: MainActorMessage>(_ message: Message, subject: Message.Subject)
        where Message.Subject: AnyObject
    
    @MainActor
    public func post<Message: MainActorMessage>(_ message: Message, subject: Message.Subject.Type = Message.Subject.self)

    // AsyncMessage post()

    public func post<Message: AsyncMessage>(_ message: Message, subject: Message.Subject)
        where Message.Subject: AnyObject
    
    public func post<Message: AsyncMessage>(_ message: Message, subject: Message.Subject.Type = Message.Subject.self)
}
```

Unlike `addObserver`, these methods do not use `MessageIdentifier` static members for message lookup because posting messages requires directly initializing `Message` types.

While both `post()` methods are called synchronously, only the `MainActorMessage` overload delivers synchronously. Posting an `AsyncMessage`, as suggested by the name, will result in asynchronous delivery.

### Interoperability with `Notification`

Clients can migrate information to and from existing `Notification` types using `makeMessage(:Notification)` and `makeNotification(:Self)`. Implementing these enables the mixing of posters and observers between the `Notification` and `Message`-style types:

```swift
struct EventDidOccur: NotificationCenter.MainActorMessage {
    var foo: Foo
    ...

    static func makeMessage(_ notification: Notification) -> Self? {
        guard let foo = notification.userInfo["foo"] as? Foo else { return nil }
        return Self(foo: foo)
    }
    
    static func makeNotification(_ message: Self) -> Notification {
        return Notification(name: Self.name, userInfo: ["foo": self.foo])
    }
}
```

These methods do not need to be implemented if all posters and observers are using `Message`-style types.

See the table below for the effects of implementing `makeMessage(:Notification)` / `makeNotification(:Self)`:

| Posting...    | Observing...    | Behavior |
| ------------- | --------------- | ------------------------------------------ |
| Message       | Notification    | Notification observers will receive the result of `makeNotification(:Self)` if available, else they will be called with a `nil` value for `userInfo` |
| Notification  | Message         | Message observers will receive the result of `makeMessage(:Notification)` if available, else the observer will not be called |

### Isolation from non-Swift Concurrency posters

Observers called via the existing, pre-Swift Concurrency `.post()` methods are either called on the same thread as the poster, or called in an explicitly passed `OperationQueue`.

However, users can still adopt `Message`-style types with pre-Swift Concurrency `.post()` calls by providing a `Message`-style type with the proper `Notification.Name` value and picking the correct type between `MainActorMessage` and `AsyncMessage`.

For example, if an Objective-C method calls the `post(name:object:userInfo:)` method on the main thread, `NotificationCenter.MainActorMessage` can be used to define a message with the same `Notification.Name`, enabling clients observing the message to access the `object` and `userInfo` parameters of the original `Notification` in a safe manner through `makeMessage(:Notification)`.

## Impact on existing code

These changes are entirely additive but could impact existing code due to the ability to interoperate between `Message`-style types and `Notification`.

If an observer receives a message posted as a `Notification` which violates the isolation contract specified in `NotificationCenter.MainActorMessage` / `NotificationCenter.AsyncMessage`, the correct fix may be to modify the existing `Notification` `.post()` call to uphold that contract.

## Future directions

None at this time.

## Alternatives considered

### Use generic isolation to support actor instances and other global actors
A previous iteration of this proposal stored an `Actor`-conforming type on a `Message` protocol, enabling `addObserver()` and `post()` to declare `isolated` parameters conforming to the given type. This enabled a flexible form of generic isolation, enabling the use of arbitrary global actors, as well as isolating to instances of an actor:

```swift
public func addObserver<MessageType: NotificationCenter.Message>(
        _ notification: MessageType.Type,
        observer: @Sendable @escaping (MessageType, isolated MessageType.Isolation) -> Void
    ) -> ObservationToken

public func post<MessageType: NotificationCenter.Message>(_ message: MessageType,
                                                          isolation: isolated MessageType.Isolation)
```

Unfortunately, the design required careful handling to use correctly and had some ergonomic shortcomings:
 * The use of an `isolated` parameter enables the checking of an `Actor`-conforming type, but not the specific instance of an isolation, making it possible to `post()` with the wrong isolation. `assertIsolated()`/`assumeIsolated()` could be used to mitigate this behavior somewhat.
 * The `isolated` parameter value should really have a default value of `message.isolation` but it is not possible to cross-referencing parameter values this way in Swift today.
 * The use of `isolated` in the observer closure requires passing in an `Actor` type that the client likely does not need.

### Use `MainActorMessage`/`AsyncMessage` directly for static member lookup
The `addObserver()` static member lookup experience requires there be a type initialized as the value of the given static member:

```swift
addObserver(of: workspace, for: .willLaunchApplication) { ... }

// .willLaunchApplication provided by ...
extension NotificationCenter.MessageIdentifier
    where Self == NotificationCenter.BaseMessageIdentifier<NSWorkspace.WillLaunchApplication, NSWorkspace> {
    static var willLaunchApplication: Self { .init() }
}
```

Alternatively, we could extend the `Message`-style protocols directly, and have the static variable return a specific `Message`-style type, removing the need for the `MessageIdentifier` protocol and `BaseMessageIdentifier` struct.

However, this puts initializer requirements on the `Message`-style type for the purposes of an optional lookup API, which could encourage developers to declare properties of their `Message` types as `Optional` when they shouldn't be. It also requires initializing and discarding a `Message` variable, which may be needless.

### Deliver `subject` as a separate parameter to observers
The current proposal splits out the subject of a message in the `addObserver()` overload but does not split it out in the observer closure nor the `post()` method:

```swift
// Subject is a separate parameter for addObserver() call, but not closure ...
center.addObserver(of: someSubject, for: .someMessage) { message in ... }

// Nor post() ...
center.post(SomeMessage())
```

We could alternatively ferry `subject` in both the observer closure and `post()` function:

```swift
// Subject is a separate parameter for addObserver() call, but not closure ...
center.addObserver(of: someSubject, for: .someMessage) { message, subject in ... }

// Nor post() ...
center.post(SomeMessage(), subject: someSubject)
```

However, not all messages have subject instances (e.g. `addObserver(of: NSWindow.self, for: .willMove)`). While `post()` could take a default parameter for an optional `subject`, the `addObserver()` closure would always have to specify a `subject` parameter even for messages without subject instances.

Further, even messages with subjects do not necessarily need their observers to access the subject instance.

Finally, developers always have the choice of including the subject in the design of their `Message`-style types if they'd like. For these reasons, we've opted not to ferry `subject` through the API.
