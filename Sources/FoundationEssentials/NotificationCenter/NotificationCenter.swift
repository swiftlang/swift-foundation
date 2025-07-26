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

#if canImport(os)
internal import os.log

extension NotificationCenter {
    internal static let logger: Logger = {
        Logger(subsystem: "com.apple.foundation", category: "notification-center")
    }()
}
#endif

#if !FOUNDATION_FRAMEWORK

internal import Synchronization

// Dictionary storage with automatic key generation
private struct AutoDictionary<Value> {
    private var storage: [UInt64: Value] = [:]
    private var nextKey: UInt64 = 0
    private var salvagedKeys: [UInt64] = []
    
    // Effectively O(1), worst case O(n)
    mutating func insert(_ value: Value) -> UInt64 {
        guard storage.count <= UInt64.max else { fatalError("Exceeded maximum storage size") }

        var key = salvagedKeys.popLast()
        while(key != nil) {
            if let key, storage[key] == nil {
                storage[key] = value
                return key
            } else {
                key = salvagedKeys.popLast()
            }
        }
        
        while(storage[nextKey] != nil) {
            if nextKey == UInt64.max { nextKey = 0 }
            nextKey += 1
        }
        
        storage[nextKey] = value
        return nextKey
    }
    
    mutating func remove(_ key: UInt64) {
        if(storage[key] != nil) {
            storage[key] = nil
            salvagedKeys.append(key)
        }
    }

    func count() -> Int {
        return storage.count
    }
    
    var values: [Value] {
        return storage.compactMap(\.value)
    }
}

private let _defaultCenter = NotificationCenter()

private struct MessageBox {
    // Equivalent to storing Message in Notification.userInfo
    let message: Any
}

open class NotificationCenter: @unchecked Sendable {
    private let registrar: Mutex<[String? /* Notification name */: [ObjectIdentifier? /* object */ : AutoDictionary<@Sendable (MessageBox) -> Void>]]>
    internal lazy var _actorQueueManager = _NotificationCenterActorQueueManager()
    
    public required init() {
        registrar = .init([:])
    }
    
    open class var `default`: NotificationCenter {
        return _defaultCenter
    }

    // 'M' may be a concrete NotificationCenter message or a Notification passed via swift-corelibs-foundation
    @_spi(SwiftCorelibsFoundation) public func _addObserver<M>(_ name: String?, object: Any?, using block: @escaping @Sendable (M) -> Void) -> _NotificationObserverToken {
        nonisolated(unsafe) let object = object
        let objectId = object.map { ObjectIdentifier($0 as AnyObject) }
        
        let token = registrar.withLock { _registrar in
            return _registrar[name, default: [:]][objectId, default: AutoDictionary<@Sendable (MessageBox) -> Void>()].insert { box in
                block(box.message as! M)
            }
        }
        
        return _NotificationObserverToken(token: token, name: name, objectId: objectId)
    }
    
    @_spi(SwiftCorelibsFoundation) public func _removeObserver(_ token: _NotificationObserverToken) {
        registrar.withLock { _registrar in
            _registrar[token.name]?[token.objectId]?.remove(token.token)
            
            if _registrar[token.name]?[token.objectId]?.count() == 0 {
                _registrar[token.name]?.removeValue(forKey: token.objectId)
                if _registrar[token.name]?.isEmpty == true {
                    _registrar.removeValue(forKey: token.name)
                }
            }
        }
    }

    @_spi(SwiftCorelibsFoundation) public func _post<M>(_ name: String?, subject: Any?, message: M) {
        // TODO: Darwin calls observers in the order they were added, mixing wildcard and non-wildcard observers.
        //       It's conceivable some users rely on that ordering.
        
        // If 'M' is a Notification, users must manually manage isolation behaviors.
        // If 'M' is a Message, this will already be the right isolation.
        nonisolated(unsafe) let subject = subject
        nonisolated(unsafe) let message = message
        
        registrar.withLock { _registrar in
            let objectId = subject.map { ObjectIdentifier($0 as AnyObject) }
            let messageBox = MessageBox(message: message)
            
            // Observers with 'name' and 'object'
            _registrar[name]?[objectId]?.values.forEach { $0(messageBox) }
            
            // Observers with wildcard name and 'object'
            _registrar[nil]?[objectId]?.values.forEach { $0(messageBox) }

            // Observers with wildcard name and wildcard object
            if subject != nil {
                _registrar[nil]?[nil]?.values.forEach { $0(messageBox) }
            }
            
            // Observers with 'name' and wildcard object
            if subject != nil {
                _registrar[name]?[nil]?.values.forEach { $0(messageBox) }
            }
        }
    }
    
    // For testing purposes only!
    internal func isEmpty() -> Bool {
        return registrar.withLock { _registrar in
            _registrar.isEmpty
        }
    }
    
    internal func _getActorQueueManager() -> _NotificationCenterActorQueueManager {
        return _actorQueueManager
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

extension NotificationCenter {
    @_spi(SwiftCorelibsFoundation) public struct _NotificationObserverToken: Equatable, Hashable, Sendable {
        let token: UInt64
        public let name: String?
        public let objectId: ObjectIdentifier?
    }
}

#endif
