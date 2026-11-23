//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

#if canImport(os) && !hasFeature(Embedded)
internal import os.log
#endif

#if FOUNDATION_FRAMEWORK && !hasFeature(Embedded)
extension NotificationCenter {
    internal static let logger: Logger = {
        Logger(subsystem: "com.apple.foundation", category: "notification-center")
    }()
}
#endif

#if !FOUNDATION_FRAMEWORK

internal import Synchronization

private let _defaultCenter = NotificationCenter()

open class NotificationCenter: @unchecked Sendable {
    private let registrar: NotificationRegistrar
    internal lazy var _actorQueueManager = _NotificationCenterActorQueueManager()
    
    public required init() {
        registrar = .init()
    }
    
    open class var `default`: NotificationCenter {
        return _defaultCenter
    }
    
    @_spi(SwiftCorelibsFoundation) public func _addObserver(_ name: String?, object: AnyObject?, using block: @escaping @Sendable (Notification) -> Void) -> UInt64 {
        return registrar.addObserver(nameHash: _notificationNameHashFor(name), name: name, object: Self._objectPointer(object), using: block).rawValue
    }
    
    @_spi(SwiftCorelibsFoundation) public func _addBlockObserver(_ name: String?, object: AnyObject?, using block: @escaping @Sendable (Notification) -> Void) -> AnyObject {
        return registrar.addObserver(nameHash: _notificationNameHashFor(name), name: name, object: Self._objectPointer(object), queue: nil, using: block)
    }

    @_spi(SwiftCorelibsFoundation) public func _removeObserver(_ token: UInt64) {
        registrar.removeObserver(Token(token))
    }
    
    @_spi(SwiftCorelibsFoundation) public func _removeObserver(_ observer: AnyObject, name: String?, object: AnyObject?) {
        registrar.removeObserver(observer, name: name, object: Self._objectPointer(object))
    }
    
    @_spi(SwiftCorelibsFoundation) public func _post(_ notification: Notification) {
        _post(notification.name.rawValue, object: notification.object) { notification }
    }
    
    internal func _post(_ name: String, object: Any?, makeNotification: () -> Notification) {
        let nameHash = _notificationNameHashFor(name)
        guard let object else {
            registrar.post(nameHash: nameHash, name: name, object: nil, makeNotification: makeNotification)
            return
        }

        // The registrar only retains the object once it has matched observers, so keep the box alive for the whole post
        let boxed = object as AnyObject
        withExtendedLifetime(boxed) {
            registrar.post(nameHash: nameHash, name: name, object: .object(Unmanaged.passUnretained(boxed)), makeNotification: makeNotification)
        }
    }
    
    // For testing purposes only!
    internal func isEmpty() -> Bool {
        return registrar.isEmpty()
    }
    
    internal func _getActorQueueManager() -> _NotificationCenterActorQueueManager {
        return _actorQueueManager
    }
    
    private static func _objectPointer(_ object: AnyObject?) -> UnsafeObjectPtr? {
        object.map { UnsafeRawPointer(Unmanaged.passUnretained($0).toOpaque()) }
    }
}

extension NotificationCenter: Equatable {
    public static func == (lhs: NotificationCenter, rhs: NotificationCenter) -> Bool {
        return lhs === rhs
    }
}

extension NotificationCenter: CustomStringConvertible {
    public var description: String {
        return "<NotificationCenter 0x\(String(UInt(bitPattern: ObjectIdentifier(self)), radix: 16))>"
    }
}

#endif

#endif // !hasFeature(Embedded)
