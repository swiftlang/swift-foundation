//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif
#if canImport(os)
internal import os.log
#endif

@available(FoundationPreview 6.2, *)
extension NotificationCenter {
    /// A protocol for creating types that you can post to a notification center, which posts them to an arbitrary isolation.
    ///
    /// You post types conforming to `AsyncMessage` to a notification center using `post(_:subject:)` and observe them with `addObserver(of:for:using:)`.
    ///
    /// The notification center delivers `AsyncMessage` types asynchronously when posted. Asynchronous delivery isn't suitable
    /// for messages with time-critical deliveries, such as a message that must have its observers called before a certain
    /// action takes place.
    ///
    /// For types that post on the main actor, use ``MainActorMessage``.
    ///
    /// Each `AsyncMessage` is associated with a specific `Subject` type.
    ///
    /// For example, an `AsyncMessage` associated with the type `Event` could use the following declaration:
    ///
    /// ```swift
    /// struct EventDidStart: NotificationCenter.AsyncMessage {
    ///     typealias Subject = Event
    /// }
    /// ```
    ///
    /// `AsyncMessage` can use an optional ``MessageIdentifier`` type for context-aware observer registration:
    ///
    /// ```swift
    /// extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<EventDidStart> {
    ///     static var didStart: Self { .init() }
    /// }
    /// ```
    ///
    /// With this identifier, observers can receive information about a specific instance by registering for this message with a ``NotificationCenter``:
    ///
    /// ```swift
    /// let observerToken = NotificationCenter.default.addObserver(of: importantEvent, for: .didStart)
    /// ````
    ///
    /// Or an observer can receive information about any instance with:
    ///
    /// ```swift
    /// let observerToken = NotificationCenter.default.addObserver(of: Event.self, for: .didStart)
    /// ```
    ///
    /// The notification center ties observation the lifetime of the returned ``NotificationCenter/ObservationToken`` and automatically de-registers the observer if the token
    /// goes out of scope. You can also remove observation explicitly:
    ///
    /// ```swift
    /// NotificationCenter.default.removeObserver(observerToken)
    /// ```
    ///
    /// ### Notification Interoperability
    ///
    /// `AsyncMessage` includes optional interoperability with ``Notification``, enabling posters and observers of both types
    /// to pass information.
    ///
    /// It does this by offering a ``makeMessage(_:)`` method that collects values from a ``Notification``'s ``Notification/userInfo`` and populates properties on a new message.
    /// In the other direction, a ``makeNotification(_:)`` method collects the message's defined properties and loads them into a new notification's ``Notification/userInfo`` dictionary.
    ///
    /// For example, if there exists a ``Notification`` posted on an arbitrary isolation identified by the ``Notification/Name`` `"eventDidFinish"` with a ``Notification/userInfo``
    /// dictionary containing the key `"duration"` as an ``NSNumber``, an app could post and observe the notification with the following ``AsyncMessage``:
    ///
    /// ```swift
    /// struct EventDidFinish: NotificationCenter.AsyncMessage {
    ///     typealias Subject = Event
    ///     static var name: Notification.Name { Notification.Name("eventDidFinish") }
    ///
    ///     var duration: Int
    ///
    ///     static func makeNotification(_ message: Self) -> Notification {
    ///         return Notification(name: Self.name, userInfo: ["duration": NSNumber(message.duration)])
    ///     }
    ///
    ///     static func makeMessage(_ notification: Notification) -> Self? {
    ///         guard let userInfo = notification.userInfo,
    ///               let duration = userInfo["duration"] as? Int
    ///         else {
    ///             return nil
    ///         }
    ///
    ///         return Self(duration: duration)
    ///     }
    /// }
    /// ```
    ///
    /// With this definition, an observer for this `AsyncMessage` type receives information even if the poster used the ``Notification`` equivalent, and vice versa.
    public protocol AsyncMessage: Sendable {
        /// A type which you can optionally post and observe along with this `AsyncMessage`.
        associatedtype Subject

#if FOUNDATION_FRAMEWORK
        /// A optional name corresponding to this type, used to interoperate with notification posters and observers.
        static var name: Notification.Name { get }
        
        /// Converts a posted notification into this asynchronous message type for any observers.
        ///
        /// To implement this method in your own `AsyncMessage` conformance, retrieve values from the ``Notification``'s ``Notification/userInfo`` and set them as properties on the message.
        /// - Parameter notification: The posted ``Notification``.
        /// - Returns: The converted `AsyncMessage`, or `nil` if conversion is not possible.
        static func makeMessage(_ notification: Notification) -> Self?

        /// Converts a posted asynchronous message into a notification for any observers.
        ///
        /// To implement this method in your own `AsyncMessage` conformance, use the properties defined by the message to populate the ``Notification``'s ``Notification/userInfo``.
        /// - Parameters:
        ///   - message: The posted `AsyncMessage`.
        /// - Returns: The converted ``Notification``.
        static func makeNotification(_ message: Self) -> Notification
#endif
    }
}

@available(FoundationPreview 6.2, *)
extension NotificationCenter.AsyncMessage {
#if FOUNDATION_FRAMEWORK
    public static func makeMessage(_ notification: Notification) -> Self? { return nil }
    public static func makeNotification(_ message: Self) -> Notification { return Notification(name: Self.name) }
    
    // Default Message name is the fully-qualified type name, suitable when Notification-compatibility isn't needed
    public static var name: Notification.Name {
        // Similar to String(describing:)
        return Notification.Name(rawValue: _typeName(Self.self))
    }
#else
    internal static var name: String {
        // Similar to String(describing:)
        return _typeName(Self.self)
    }
#endif
}

@available(FoundationPreview 6.2, *)
extension NotificationCenter {
    /// Adds an observer to a center for messages delivered asynchronously with a given subject and identifier.
    /// - Parameters:
    ///   - subject: The subject to observe. Specify a metatype to observe all values for a given type.
    ///   - identifier: An identifier representing a specific message type.
    ///   - observer: A closure to execute when receving a message.
    /// - Returns: A token representing the observation registration with the given notification center. Retain this token for as long as you need to receive messages.
    public func addObserver<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject,
        for identifier: Identifier,
        using observer: @escaping @Sendable (Message) async -> Void)
    -> ObservationToken where Identifier.MessageType == Message,
                              Message.Subject: AnyObject
    {
        _addAsyncObserver(Identifier.MessageType.self, subject: subject, observer: observer)
    }
    
    /// Adds an observer to a center for messages delivered asynchronously with a given subject and message type.
    /// - Parameters:
    ///   - subject: The metatype to observe all values for a given type.
    ///   - identifier: An identifier representing a specific message type.
    ///   - observer: A closure to execute when receving a message.
    /// - Returns: A token representing the observation registration with the given notification center. Retain this token for as long as you need to receive messages.
    public func addObserver<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject.Type,
        for identifier: Identifier,
        using observer: @escaping @Sendable (Message) async -> Void)
    -> ObservationToken where Identifier.MessageType == Message {
        _addAsyncObserver(Identifier.MessageType.self, subject: nil, observer: observer)
    }
    
    /// Adds an observer to a center for messages delivered asynchronously with a given subject and message type.
    /// - Parameters:
    ///   - subject: The subject to observe. Specify a metatype to observe all values for a given type.
    ///   - messageType: The message type to be observed.
    ///   - observer: A closure to execute when receving a message.
    /// - Returns: A token representing the observation registration with the given notification center.  Retain this token for as long as you need to receive messages.
    public func addObserver<Message: AsyncMessage>(
        of subject: Message.Subject? = nil,
        for messageType: Message.Type,
        using observer: @escaping @Sendable (Message) async -> Void)
    -> ObservationToken where Message.Subject: AnyObject {
        _addAsyncObserver(Message.self, subject: subject, observer: observer)
    }

    /// Posts a given asynchronous message to the notification center.
    /// - Parameters:
    ///   - message: The message to post.
    ///   - subject: The subject instance that corresponds to the message.
    public func post<Message: AsyncMessage>(_ message: Message, subject: Message.Subject) where Message.Subject: AnyObject {
        _post(message: message, subject: subject)
    }

    /// Posts a given asynchronous message to the notification center.
    /// - Parameters:
    ///   - message: The message to post.
    public func post<Message: AsyncMessage>(_ message: Message) {
        _post(message: message)
    }
}

extension NotificationCenter {
    fileprivate func _addAsyncObserver<Message: AsyncMessage>(
        _ messageType: Message.Type,
        subject: Message.Subject?,
        observer: @escaping @Sendable (Message) async -> Void
    ) -> ObservationToken {
        ObservationToken(center: self, token: _addObserver(Message.name, object: subject) { payload in
#if FOUNDATION_FRAMEWORK
            guard
                let payload: Message = NotificationCenter._messageFromNotification(payload)
            else { return }
#endif
            self.asyncObserverQueue.enqueue {
                await observer(payload)
            }
        })
    }
    
#if FOUNDATION_FRAMEWORK
    internal static func _messageFromNotification<Message: NotificationCenter.AsyncMessage>(_ notification: Notification) -> Message? {
        if let m = notification.userInfo?[NotificationMessageKey.key] as? Message {
            // Message posted, message observed
            return m
        } else if let m = Message.makeMessage(notification) {
            // Notification posted, message observed
            return m
        } else {
            // Notification posted, unable to make a message
            os_log(.fault, log: _NSRuntimeIssuesLog(), "Unable to deliver Notification to Message observer because \(String(describing: Message.self)).makeMessage() returned nil. If this is unexpected, check or provide an implementation of makeMessage() which returns a non-nil value for this notification's payload.")
            return nil
        }
    }
#endif
    
    fileprivate func _post<M: AsyncMessage>(message: M, subject: M.Subject? = nil) {
#if FOUNDATION_FRAMEWORK
        var notification = M.makeNotification(message)

        notification.name = M.name
        notification.object = subject
        
        var userInfo = notification.userInfo.take() ?? [:]
        userInfo[NotificationMessageKey.key] = message
        notification.userInfo = userInfo
        
        post(notification)
#else
        _post(M.name, subject: subject, message: message)
#endif
    }
}
