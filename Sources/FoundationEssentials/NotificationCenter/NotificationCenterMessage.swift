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
internal import Foundation_Private.NSNotification
internal import _ForSwiftFoundation
#endif
#if canImport(os)
internal import os.log
#endif

@available(FoundationPreview 6.2, *)
extension NotificationCenter {
    /// An optional identifier to associate a given message with a given type.
    ///
    /// Implement a `MessageIdentifier` to provide a typed, ergonomic experience at the call point, as described in [SE-0299](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0299-extend-generic-static-member-lookup.md).
    ///
    /// For example, given `ExampleMessage` with a `Subject` called `ExampleSubject`:
    ///
    /// ```swift
    /// extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<ExampleMessage> {
    ///     static var eventDidOccur: Self { .init() }
    /// }
    /// ```
    ///
    /// This simplifies the call point for clients, as seen here:
    ///
    /// ```swift
    /// let token = center.addObserver(of: exampleSubject, for: .eventDidOccur) { ... }
    /// ```
    public protocol MessageIdentifier {
        associatedtype MessageType
    }
    
    /// A type for use when defining optional Message identifiers.
    ///
    /// See ``MessageIdentifier`` for an example of how to use this type when defining your own message identifiers.
    public struct BaseMessageIdentifier<MessageType>: MessageIdentifier, Sendable {
        public init() where MessageType: MainActorMessage {}
        public init() where MessageType: AsyncMessage {}
    }
}

extension NotificationCenter {
#if !FOUNDATION_FRAMEWORK
    internal typealias _NSNotificationObserverToken = _NotificationObserverToken
#endif
    
    /// A unique token representing a single observer registration in a notification center.
    ///
    /// You receive the `ObservationToken` type as a return value from `addObserver(of:for:using:)` and related methods.
    ///
    /// Retain the `ObservationToken` for as long as you need to continue observation, since observation ends when the token goes out of scope.
    /// You can also explicitly stop observing by passing the token to ``removeObserver(_:)-(ObservationToken)``.
    @available(FoundationPreview 6.2, *)
    public struct ObservationToken: Hashable, Sendable {
        private let tokenWrapper: _NSNotificationObserverTokenWrapper
        internal var center: NotificationCenter? { self.tokenWrapper.center }

        internal init(center: NotificationCenter, token: _NSNotificationObserverToken) {
            self.tokenWrapper = _NSNotificationObserverTokenWrapper(center: center, token: token)
        }
        
        internal func remove() {
            self.tokenWrapper.remove()
        }

        fileprivate final class _NSNotificationObserverTokenWrapper: Hashable, @unchecked Sendable {
            internal var token: _NSNotificationObserverToken?
            fileprivate weak var center: NotificationCenter?

            init(center: NotificationCenter, token: _NSNotificationObserverToken) {
                self.token = token
                self.center = center
            }
            
            func remove() {
                if let value = token {
                    self.center?._removeObserver(value)
                    token = nil
                }
            }

            deinit {
                self.remove()
            }

            static func == (lhs: ObservationToken._NSNotificationObserverTokenWrapper, rhs: ObservationToken._NSNotificationObserverTokenWrapper) -> Bool {
                return lhs.token == rhs.token
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(token)
            }
        }
    }
    
    /// Stops the observation represented by the given observation token.
    ///
    /// - Parameter token: a unique token representing a specific observer in a specific notification center. You receive this type from prior calls to `addObserver(of:for:using:)`.
    @available(FoundationPreview 6.2, *)
    public func removeObserver(_ token: ObservationToken) {
        guard token.center == nil || token.center == self else {
#if canImport(os)
            NotificationCenter.logger.fault("Unable to remove observer. The provided token does not belong to this notification center. Expected: <\(_typeName(Self.self)) 0x\(String(UInt(bitPattern: ObjectIdentifier(token.center!)), radix: 16))>, got <\(_typeName(Self.self)) 0x\(String(UInt(bitPattern: ObjectIdentifier(self)), radix: 16))>.")
#endif
            return
        }

        token.remove()
    }
}

extension NotificationCenter {
#if FOUNDATION_FRAMEWORK
    internal final class NotificationMessageKey: NSObject, NSCopying, Sendable {
        func copy(with zone: NSZone? = nil) -> Any { return self }

        static let key = NotificationMessageKey()
    }
#else
    internal final class NotificationMessageKey: Sendable {
        static var key: ObjectIdentifier { ObjectIdentifier(NotificationCenter.NotificationMessageKey.self) }
    }
#endif
}

extension NotificationCenter {
    internal var asyncObserverQueue: _NotificationCenterActorQueueManager {
        self._getActorQueueManager() as! _NotificationCenterActorQueueManager
    }
}
