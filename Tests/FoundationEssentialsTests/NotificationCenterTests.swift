// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable @_spi(SwiftCorelibsFoundation) import FoundationEssentials
#endif

import Testing

fileprivate final class TestObject: Sendable {}

@Suite("NotificationCenter", .timeLimit(.minutes(1)))
private struct NotificationCenterTests {
    @Test func defaultCenter() {
        let defaultCenter1 = NotificationCenter.default
        let defaultCenter2 = NotificationCenter.default
        #expect(defaultCenter1 == defaultCenter2)
    }

    @Test func equality() {
        let center1 = NotificationCenter()
        let center2 = NotificationCenter()
        #expect(center1 != center2)
    }

#if !FOUNDATION_FRAMEWORK
    @Test func internalPostNotification() {
        nonisolated(unsafe) var flag = false

        let notificationName = "test_postNotification_name"
        let center = NotificationCenter()
        let testObject = TestObject()
        let message = MainActorTestMessage(payloadInt: 1, payloadString: "one")
        
        // name and object
        var token = center._addObserver(notificationName, object: testObject) { (message: MainActorTestMessage) in
            #expect(message.payloadInt == 1)
            #expect(message.payloadString == "one")
            flag = true
        }
        flag = false
        center._post(notificationName, subject: testObject, message: message)
        #expect(flag)
        center._removeObserver(token)
        
        // nil name and object
        token = center._addObserver(nil, object: testObject) { (message: MainActorTestMessage) in
            #expect(message.payloadInt == 1)
            #expect(message.payloadString == "one")

            flag = true
        }
        flag = false
        center._post(notificationName, subject: testObject, message: message)
        #expect(flag)
        center._removeObserver(token)

        // nil name and nil object
        token = center._addObserver(nil, object: nil) { (message: MainActorTestMessage) in
            #expect(message.payloadInt == 1)
            #expect(message.payloadString == "one")

            flag = true
        }
        flag = false
        center._post(notificationName, subject: testObject, message: message)
        #expect(flag)
        center._removeObserver(token)

        // name and nil object
        token = center._addObserver(notificationName, object: nil) { (message: MainActorTestMessage) in
            #expect(message.payloadInt == 1)
            #expect(message.payloadString == "one")

            flag = true
        }
        flag = false
        center._post(notificationName, subject: testObject, message: message)
        #expect(flag)
        center._removeObserver(token)
    }
    
    @Test func internalRemoveObserver() {
        nonisolated(unsafe) var flag = false

        let notificationName = "test_postNotification_name"
        let center = NotificationCenter()
        let testObject = TestObject()
        let message = MainActorTestMessage(payloadInt: 1, payloadString: "one")
        
        let token = center._addObserver(notificationName, object: testObject) { (message: MainActorTestMessage) in
            #expect(message.payloadInt == 1)
            #expect(message.payloadString == "one")

            flag = true
        }
        
        flag = false
        center._post(notificationName, subject: testObject, message: message)
        #expect(flag)
        center._removeObserver(token)
        
        flag = false
        center._post(notificationName, subject: testObject, message: message)
        #expect(!flag)
    }

    @Test func internalPostNotificationForObject() {
        let center = NotificationCenter()
        let name = "test_postNotificationForObject_name"
        let testObject = TestObject()
        let testObject2 = TestObject()
        let message = MainActorTestMessage(payloadInt: 1, payloadString: "one")

        nonisolated(unsafe) var flag = true
        
        let observer = center._addObserver(name, object: testObject) { (message: MainActorTestMessage) in
            flag = false
        }
        
        center._post(name, subject: testObject2, message: message)
        #expect(flag)
        
        center._removeObserver(observer)
    }

    @Test func internalPostNotificationForValue() {
        let center = NotificationCenter()
        let name = "test_postNotificationForObject_name"
        let message = MainActorTestMessage(payloadInt: 1, payloadString: "one")

        nonisolated(unsafe) var literal5Observed = false
        nonisolated(unsafe) var literal1024Observed = false
        
        let literal5Observer = center._addObserver(name, object: 5) { (message: MainActorTestMessage) in
            literal5Observed = true
        }
        let literal1024Observer = center._addObserver(name, object: 1024) { (message: MainActorTestMessage) in
            literal1024Observed = true
        }
        
        center._post(name, subject: 5, message: message)
        #expect(literal5Observed)
        #expect(!literal1024Observed)
        
        center._removeObserver(literal5Observer)
        center._removeObserver(literal1024Observer)
    }

    @Test func internalPostMultipleNotifications() {
        let center = NotificationCenter()
        let name = "test_postMultipleNotifications_name"
        let message = MainActorTestMessage(payloadInt: 1, payloadString: "one")
        
        nonisolated(unsafe) var observer1Called = false

        let observer1 = center._addObserver(name, object: nil) { (message: MainActorTestMessage) in
            observer1Called = true
        }
        
        nonisolated(unsafe) var observer2Called = false
        let observer2 = center._addObserver(name, object: nil) { (message: MainActorTestMessage) in
            observer2Called = true
        }
        
        nonisolated(unsafe) var observer3Called = false
        let observer3 = center._addObserver(name, object: nil) { (message: MainActorTestMessage) in
            observer3Called = true
        }
        
        center._removeObserver(observer2)
        
        center._post(name, subject: nil, message: message)
        #expect(observer1Called)
        #expect(!observer2Called)
        #expect(observer3Called)
        
        center._removeObserver(observer1)
        center._removeObserver(observer3)
    }

    @Test func internalAddObserverForNilName() {
        let center = NotificationCenter()
        let name = "test_addObserverForNilName_name"
        let invalidName = "test_addObserverForNilName_name_invalid"
        let message = MainActorTestMessage(payloadInt: 1, payloadString: "one")
        
        nonisolated(unsafe) var flag1 = false
        let observer1 = center._addObserver(name, object: nil) { (message: MainActorTestMessage) in
            flag1 = true
        }
        
        nonisolated(unsafe) var flag2 = true
        let observer2 = center._addObserver(invalidName, object: nil) { (message: MainActorTestMessage) in
            flag2 = false
        }
        
        nonisolated(unsafe) var flag3 = false
        let observer3 = center._addObserver(nil, object: nil) { (message: MainActorTestMessage) in
            flag3 = true
        }
        
        center._post(name, subject: nil, message: message)
        #expect(flag1)
        #expect(flag2)
        #expect(flag3)
        
        center._removeObserver(observer1)
        center._removeObserver(observer2)
        center._removeObserver(observer3)
    }
#endif
    
    @MainActor
    @Test func uniqueActorQueuePerCenter() {
        let center1 = NotificationCenter()
        let center2 = NotificationCenter()
        
        #expect(center1.asyncObserverQueue !== center2.asyncObserverQueue)
    }
}
