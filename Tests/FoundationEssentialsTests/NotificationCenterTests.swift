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

@Suite("NotificationCenter", .timeLimit(.minutes(2)))
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
        
        // name and object
        var token = center._addObserver(notificationName, object: testObject) { notification in
            #expect(notification.name.rawValue == notificationName)
            flag = true
        }
        flag = false
        center._post(Notification(name: Notification.Name(notificationName), object: testObject))
        #expect(flag)
        center._removeObserver(token)
        
        // nil name and object
        token = center._addObserver(nil, object: testObject) { notification in
            #expect(notification.name.rawValue == notificationName)

            flag = true
        }
        flag = false
        center._post(Notification(name: Notification.Name(notificationName), object: testObject))
        #expect(flag)
        center._removeObserver(token)

        // nil name and nil object
        token = center._addObserver(nil, object: nil) { notification in
            #expect(notification.name.rawValue == notificationName)

            flag = true
        }
        flag = false
        center._post(Notification(name: Notification.Name(notificationName), object: testObject))
        #expect(flag)
        center._removeObserver(token)

        // name and nil object
        token = center._addObserver(notificationName, object: nil) { notification in
            #expect(notification.name.rawValue == notificationName)

            flag = true
        }
        flag = false
        center._post(Notification(name: Notification.Name(notificationName), object: testObject))
        #expect(flag)
        center._removeObserver(token)
    }
    
    @Test func internalRemoveObserver() {
        nonisolated(unsafe) var flag = false

        let notificationName = "test_postNotification_name"
        let center = NotificationCenter()
        let testObject = TestObject()
        
        let token = center._addObserver(notificationName, object: testObject) { notification in
            #expect(notification.name.rawValue == notificationName)

            flag = true
        }
        
        flag = false
        center._post(Notification(name: Notification.Name(notificationName), object: testObject))
        #expect(flag)
        center._removeObserver(token)
        
        flag = false
        center._post(Notification(name: Notification.Name(notificationName), object: testObject))
        #expect(!flag)
    }

    @Test func internalPostNotificationForObject() {
        let center = NotificationCenter()
        let name = "test_postNotificationForObject_name"
        let testObject = TestObject()
        let testObject2 = TestObject()

        nonisolated(unsafe) var flag = true
        
        let observer = center._addObserver(name, object: testObject) { notification in
            flag = false
        }
        
        center._post(Notification(name: Notification.Name(name), object: testObject2))
        #expect(flag)
        
        center._removeObserver(observer)
    }

    @Test func internalPostMultipleNotifications() {
        let center = NotificationCenter()
        let name = "test_postMultipleNotifications_name"
        
        nonisolated(unsafe) var observer1Called = false

        let observer1 = center._addObserver(name, object: nil) { notification in
            observer1Called = true
        }
        
        nonisolated(unsafe) var observer2Called = false
        let observer2 = center._addObserver(name, object: nil) { notification in
            observer2Called = true
        }
        
        nonisolated(unsafe) var observer3Called = false
        let observer3 = center._addObserver(name, object: nil) { notification in
            observer3Called = true
        }
        
        center._removeObserver(observer2)
        
        center._post(Notification(name: Notification.Name(name), object: nil))
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
        
        nonisolated(unsafe) var flag1 = false
        let observer1 = center._addObserver(name, object: nil) { notification in
            flag1 = true
        }
        
        nonisolated(unsafe) var flag2 = true
        let observer2 = center._addObserver(invalidName, object: nil) { notification in
            flag2 = false
        }
        
        nonisolated(unsafe) var flag3 = false
        let observer3 = center._addObserver(nil, object: nil) { notification in
            flag3 = true
        }
        
        center._post(Notification(name: Notification.Name(name), object: nil))
        #expect(flag1)
        #expect(flag2)
        #expect(flag3)
        
        center._removeObserver(observer1)
        center._removeObserver(observer2)
        center._removeObserver(observer3)
    }

    @MainActor
    @Test func internalWildcardNameObserverReceivesMessagePost() {
        nonisolated(unsafe) var receivedName: String?

        let center = NotificationCenter()

        let observer = center._addObserver(nil, object: nil) { notification in
            receivedName = notification.name.rawValue
        }

        center.post(MainActorTestMessage(payloadInt: 1, payloadString: "one"))
        #expect(receivedName == _typeName(MainActorTestMessage.self))

        center._removeObserver(observer)
    }
#endif
    
    @MainActor
    @Test func uniqueActorQueuePerCenter() {
        let center1 = NotificationCenter()
        let center2 = NotificationCenter()
        
        #expect(center1.asyncObserverQueue !== center2.asyncObserverQueue)
    }
    
#if FOUNDATION_FRAMEWORK
    // Foundation.framework only: swift-foundation has no Notification type. swift-corelibs-foundation should run these too.
    
    @Test func postPreservesObserverOrder() {
        let center = NotificationCenter()
        let notifName = NSNotification.Name("SomethingDidOccur")
        let notifObject = NSObject()
        
        nonisolated(unsafe) var postRecord: [Int] = []
        
        var tokens: [NSObjectProtocol] = []
        
        for i in 0..<250 {
            // 70% chance we add an observer, 30% we remove a random observer
            if Int.random(in: 0..<100) > 30 {
                // Pick a "variant" of observer, e.g. name vs nil-name, object vs nil-object
                let observerVariant = i % 4
                
                // name, nil = 0
                // name, object = 1
                // nil, object = 2
                // nil, nil = 3
                
                let name: NSNotification.Name? = (observerVariant == 0) || (observerVariant == 1) ? notifName : nil
                let object: AnyObject? = (observerVariant == 1) || (observerVariant == 2) ? notifObject : nil
                
                tokens.append(center.addObserver(forName: name, object: object, queue: nil) { notification in
                    postRecord.append(i)
                })
            } else {
                // Don't remove every last token, else we won't be able to test order
                if tokens.count > 5 {
                    let token = tokens.remove(at: Int.random(in: 0..<tokens.count))
                    center.removeObserver(token)
                }
            }
        }
        
        // Do a quick check to ensure we have observers at all ...
        center.post(name: notifName, object: notifObject)
        #expect(postRecord.count >= 5)
        postRecord.removeAll()
        
        // Instead of testing a single post, we continually post while drawing down the registrar.
        // This ensures a shrinking registrar doesn't lose posting ordering either.
        while(center.isEmpty() == false) {
            center.post(name: notifName, object: notifObject)
            
            for (prev, next) in zip(postRecord, postRecord.dropFirst()) {
                #expect(prev < next)
            }
            
            //#expect(postRecord.count == center._observerCount)
            
            // Take one down, pass it around
            let token = tokens.removeLast()
            center.removeObserver(token)
            
            postRecord.removeAll()
        }
    }
    
    @Test func reentrantPostToDifferentNameDelivers() {
        let center = NotificationCenter()
        
        nonisolated(unsafe) var receiveCountA = 0
        nonisolated(unsafe) var receiveCountB = 0
        
        let observerB = center.addObserver(forName: Notification.Name("b"), object: nil, queue: nil) { _ in
            receiveCountB += 1
        }
        let observerA = center.addObserver(forName: Notification.Name("a"), object: nil, queue: nil) { _ in
            receiveCountA += 1
            center.post(name: Notification.Name("b"), object: nil)
        }
        
        center.post(name: Notification.Name("a"), object: nil)
        
        #expect(receiveCountA == 1)
        #expect(receiveCountB == 1)
        
        center.removeObserver(observerA)
        center.removeObserver(observerB)
    }
    
    @Test func reentrantPostToSameNameIsBounded() {
        let center = NotificationCenter()
        
        nonisolated(unsafe) var received = 0
        
        let observer = center.addObserver(forName: Notification.Name("a"), object: nil, queue: nil) { _ in
            received += 1
            if received < 3 {
                center.post(name: Notification.Name("a"), object: nil)
            }
        }
        
        center.post(name: Notification.Name("a"), object: nil)
        #expect(received == 3)
        
        center.removeObserver(observer)
    }
    
    @Test func addObserverDuringPostSkipsInFlightPost() {
        let center = NotificationCenter()

        nonisolated(unsafe) var receiveCountA = 0
        nonisolated(unsafe) var receiveCountB = 0
        nonisolated(unsafe) var addedB = false
        
        _ = center.addObserver(forName: Notification.Name("a"), object: nil, queue: nil) { _ in
            receiveCountA += 1

            if !addedB {
                addedB = true
                _ = center.addObserver(forName: Notification.Name("a"), object: nil, queue: nil) { _ in
                    receiveCountB += 1
                }
            }
        }
        
        center.post(name: Notification.Name("a"), object: nil)

        #expect(receiveCountA == 1)
        #expect(receiveCountB == 0)
        
        center.post(name: Notification.Name("a"), object: nil)

        #expect(receiveCountA == 2)
        #expect(receiveCountB == 1)
    }
#endif
}
