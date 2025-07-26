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
@testable import Foundation
import Foundation_Private
#else
@testable import FoundationEssentials
#endif

import Testing

// MARK: Test data (Subjects, Messages, MessageIdentifiers, NotificationNames)

final class MessageTestSubject: Sendable, Equatable {
    let uuid = UUID()
    
    static func == (lhs: MessageTestSubject, rhs: MessageTestSubject) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
final class AsyncMessageTestSubject: Sendable, Equatable {
    let uuid = UUID()
    
    static func == (lhs: AsyncMessageTestSubject, rhs: AsyncMessageTestSubject) -> Bool {
        lhs.uuid == rhs.uuid
    }
}

struct MainActorTestMessage: NotificationCenter.MainActorMessage {
    typealias Subject = MessageTestSubject
    
    var payloadInt: Int
    var payloadString: String
}
extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<MainActorTestMessage> {
    static var messagePosted: Self { .init() }
}

struct MainActorTestNotificationMessage: NotificationCenter.MainActorMessage {
    typealias Subject = MessageTestSubject
    
    var payloadInt: Int
    var payloadString: String
    
#if FOUNDATION_FRAMEWORK
    static var name: Notification.Name { Notification.Name("MainActorTestMessageNotification") }
    
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let userInfo = notification.userInfo,
              let payloadInt = userInfo["payloadInt"] as? Int,
              let payloadString = userInfo["payloadString"] as? String
        else {
            return nil
        }
        
        return Self(payloadInt: payloadInt, payloadString: payloadString)
    }
    
    public static func makeNotification(_ message: Self) -> Notification {
        return Notification(name: MainActorTestNotificationMessage.name, userInfo: ["payloadInt": message.payloadInt, "payloadString": message.payloadString])
    }
#endif
}
extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<MainActorTestNotificationMessage> {
    static var notificationMessagePosted: Self { .init() }
}

struct AsyncTestMessage: NotificationCenter.AsyncMessage {
    typealias Subject = AsyncMessageTestSubject

    var payloadInt: Int
    var payloadString: String
}
extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<AsyncTestMessage> {
    static var messagePosted: Self { .init() }
}

struct AsyncTestNotificationMessage: NotificationCenter.AsyncMessage {
    typealias Subject = AsyncMessageTestSubject

    var payloadInt: Int
    var payloadString: String

#if FOUNDATION_FRAMEWORK
    static var name: Notification.Name { Notification.Name("AsyncTestMessageNotification") }

    static func makeNotification(_ message: Self) -> Notification {
        return Notification(name: Self.name, userInfo: ["payloadInt": message.payloadInt, "payloadString": message.payloadString])
    }

    static func makeMessage(_ notification: Notification) -> Self? {
        guard let userInfo = notification.userInfo,
              let payloadInt = userInfo["payloadInt"] as? Int,
              let payloadString = userInfo["payloadString"] as? String
        else {
            return nil
        }

        return Self(payloadInt: payloadInt, payloadString: payloadString)
    }
#endif
}
extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<AsyncTestNotificationMessage> {
    static var notificationMessagePosted: Self { .init() }
}

#if FOUNDATION_FRAMEWORK
let nonConvertingMessageNotificationName = Notification.Name("NonConvertingMessage")
struct NonConvertingMessage: NotificationCenter.MainActorMessage {
    static var name: Notification.Name { nonConvertingMessageNotificationName }
    typealias Subject = MessageTestSubject
}
extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<NonConvertingMessage> {
    static var nonConvertingMessage: Self { .init() }
}
#endif

@Suite("NotificationCenterMessage", .timeLimit(.minutes(1)))
private struct NotificationCenterMessageTests {

    // MARK: - Basic capabilities (using MainActorMessage)
    
    @MainActor
    @Test func postWithSubjectTypeAndObserveWithSubjectType() async throws {
        await confirmation("expected message to be observed") { messageObserved in
            var mutableState: Int = 0
            let center = NotificationCenter()
            
            let token = center.addObserver(of: MessageTestSubject.self, for: .messagePosted) { message in
                MainActor.assertIsolated()
                mutableState += 1
                messageObserved()
            }
            
            MainActor.assertIsolated()
            center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"))
            #expect(mutableState == 1)
            
            center.removeObserver(token)
        }
    }

    @MainActor
    @Test func postWithSubjectInstanceAndObserveWithSubjectInstance() async throws {
        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            let testSubject = MessageTestSubject()
            
            let token = center.addObserver(of: testSubject, for: .messagePosted) { message in
                #expect(message.payloadInt == 1)
                messageObserved()
            }
            
            center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
            
            center.removeObserver(token)
        }
    }

    @MainActor
    @Test func postWithSubjectInstanceAndObserveDifferentSubjectInstance() async throws {
        var messageObserved = false
        let center = NotificationCenter()
        
        let observedSubject = MessageTestSubject()
        let postedSubject = MessageTestSubject()
        
        let token = center.addObserver(of: observedSubject, for: .messagePosted) { message in
            messageObserved = true
        }
        
        center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"), subject: postedSubject)
        
        center.removeObserver(token)
        
        #expect(messageObserved == false)
    }
    
    @MainActor
    @Test func postWithSubjectInstanceAndObserveWithSubjectType() async throws {
        await confirmation("expected message to be observed", expectedCount: 2) { messageObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(of: MessageTestSubject.self, for: .messagePosted) { message in
                messageObserved()
            }
            
            let testSubject = MessageTestSubject()
            center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
            
            let secondTestSubject = MessageTestSubject()
            center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"), subject: secondTestSubject)
            
            center.removeObserver(token)
        }
    }

    @MainActor
    @Test func postWithSubjectTypeAndObserveWithSubjectInstance() async throws {
        var messageObserved = false
        
        let center = NotificationCenter()
        let testSubject = MessageTestSubject()

        let token = center.addObserver(of: testSubject, for: .messagePosted) { message in
            messageObserved = true
        }

        center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"))

        center.removeObserver(token)

        #expect(messageObserved == false)
    }
    
    @MainActor
    @Test func observeWithoutMessageIdentifier() async throws {
        await confirmation("expected message to be observed", expectedCount: 2) { messageObserved in
            let center = NotificationCenter()
            
            let testSubject = MessageTestSubject()
            
            let token = center.addObserver(of: testSubject, for: MainActorTestMessage.self) { message in
                messageObserved()
            }
            let secondToken = center.addObserver(for: MainActorTestMessage.self) { message in
                messageObserved()
            }
            
            center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
            
            center.removeObserver(token)
            center.removeObserver(secondToken)
        }
    }
    
#if FOUNDATION_FRAMEWORK
    @Test func messageNameSynthesis() {
        // Synthesized Message names are expected to mirror ABI stability
        #expect(MainActorTestMessage.name.rawValue == "Unit.MainActorTestMessage")
    }
#endif

    @MainActor
    @Test func observationOccursOnMainActor() async {
        await confirmation("expected message to be observed") { messageObserved in
            actor OtherActor {
                var token: NotificationCenter.ObservationToken?
                let confirmation: Confirmation
                
                init(confirmation: Confirmation) {
                    self.confirmation = confirmation
                }
                
                func registerObservation() {
                    token = NotificationCenter.default.addObserver(of: MessageTestSubject.self, for: .messagePosted) { _ in
                        MainActor.assertIsolated()
                        self.confirmation()
                    }
                }
                
                deinit {
                    if let token { NotificationCenter.default.removeObserver(token) }
                }
            }
            
            let otherActor = OtherActor(confirmation: messageObserved)
            await otherActor.registerObservation()
            
            MainActor.assertIsolated()
            NotificationCenter.default.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"))
        }
    }
    
    // MARK: - AsyncMessage
    
    @Test func asyncMessagePostWithSubjectTypeAndObserveWithSubjectType() async throws {
        let center = NotificationCenter()
        var token: NotificationCenter.ObservationToken?
        
        await confirmation("expected message to be observed") { messageObserved in
            await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
                @Sendable func anAsyncCall() async {
                    messageObserved()
                    continuation.resume()
                }
                
                token = center.addObserver(of: AsyncMessageTestSubject.self, for: .messagePosted) { message in
                    await anAsyncCall()
                }
                
                center.post(AsyncTestMessage(payloadInt: 1, payloadString: "One"))
            }
        }
        
        if let token { center.removeObserver(token) }
    }
    
    @Test func asyncMessagePostWithSubjectInstanceAndObserveWithSubjectInstance() async throws {
        let center = NotificationCenter()
        let testSubject = AsyncMessageTestSubject()
        var token: NotificationCenter.ObservationToken?

        await confirmation("expected message to be observed") { messageObserved in
            await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
                token = center.addObserver(of: testSubject, for: .messagePosted) { message in
                    #expect(message.payloadInt == 1)
                    messageObserved()
                    continuation.resume()
                }
                
                center.post(AsyncTestMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
            }
        }
        
        if let token { center.removeObserver(token) }
    }

    @Test func asyncMessageObserveWithoutMessageIdentifier() async throws {
        let center = NotificationCenter()
        let testSubject = AsyncMessageTestSubject()
        var token: NotificationCenter.ObservationToken?
        var secondToken: NotificationCenter.ObservationToken?

        final class AtomicCounter: Sendable {
            private let count = LockedState<Int>(initialState: 0)
            
            func increment() -> Int {
                count.withLock { value in
                    value &+= 1
                    return value
                }
            }
        }

        
        await confirmation("expected message to be observed", expectedCount: 2) { messageObserved in
            await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
                let counter = AtomicCounter()
                
                token = center.addObserver(of: testSubject, for: AsyncTestMessage.self) { message in
                    messageObserved()
                    if counter.increment() == 2 { continuation.resume() }
                }
                secondToken = center.addObserver(for: AsyncTestMessage.self) { message in
                    messageObserved()
                    if counter.increment() == 2 { continuation.resume() }
                }
                
                center.post(AsyncTestMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
            }
        }

        if let token { center.removeObserver(token) }
        if let secondToken { center.removeObserver(secondToken) }
    }

    @MainActor
    @Test func asyncMessageObservesInSeparateIsolation() async throws {
        enum TaskSignifier {
            @TaskLocal static var flag: Bool = false
        }
        
        // #isolation isn't available in the observer closure, but we can verify the expected isolation change
        // by checking that a task local variable isn't preserved
        await TaskSignifier.$flag.withValue(true) {
            #expect(TaskSignifier.flag == true)

            let center = NotificationCenter()
            let testSubject = AsyncMessageTestSubject()
            var token: NotificationCenter.ObservationToken?
            
            await confirmation("expected message to be observed") { messageObserved in
                await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
                    token = center.addObserver(of: testSubject, for: AsyncTestMessage.self) { message in
                        #expect(TaskSignifier.flag == false)
                        messageObserved()
                        continuation.resume()
                    }
                    
                    MainActor.assertIsolated()
                    center.post(AsyncTestMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
                }
            }

            if let token { center.removeObserver(token) }
        }
    }
    
#if FOUNDATION_FRAMEWORK
    // MARK: - Message/Notification interoperability
    @MainActor
    @Test func postMessageWithSubjectObserveNotificationWithObject() async throws {
        await confirmation("expected notification to be observed") { notificationObserved in
            let center = NotificationCenter()
            let testSubject = MessageTestSubject()
            
            let token = center.addObserver(forName: MainActorTestNotificationMessage.name, object: testSubject, queue: nil) { notification in
                guard
                    let object: MessageTestSubject = notification.object as? MessageTestSubject,
                    let userInfo = notification.userInfo
                else { return }
                if notification.name == MainActorTestNotificationMessage.name,
                   object == testSubject,
                   userInfo["payloadInt"] as? Int == 1,
                   userInfo["payloadString"] as? String == "One"
                {
                    notificationObserved()
                }
            }
            
            center.post(MainActorTestNotificationMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
            
            center.removeObserver(token)
        }
    }

    @MainActor
    @Test func postMessageWithSubjectObserveNotificationWithoutObject() async throws {
        await confirmation("expected notification to be observed", expectedCount: 2) { notificationObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(forName: MainActorTestNotificationMessage.name, object: nil, queue: nil) { notification in
                guard
                    notification.object is MessageTestSubject,
                    notification.name == MainActorTestNotificationMessage.name
                else { return }
                
                notificationObserved()
            }
            
            let testSubject = MessageTestSubject()
            center.post(MainActorTestNotificationMessage(payloadInt: 1, payloadString: "One"), subject: testSubject)
            
            let secondTestSubject = MessageTestSubject()
            center.post(MainActorTestNotificationMessage(payloadInt: 1, payloadString: "One"), subject: secondTestSubject)
            
            center.removeObserver(token)
        }
    }

    @MainActor
    @Test func postMessageWithoutSubjectObserveNotificationWithObject() async throws {
        let center = NotificationCenter()
        let testSubject = MessageTestSubject()
        nonisolated(unsafe) var notificationObserved = false

        let token = center.addObserver(forName: MainActorTestNotificationMessage.name, object: testSubject, queue: nil) { notification in
            guard
                notification.object is MessageTestSubject,
                notification.name == MainActorTestNotificationMessage.name
            else { return }

            notificationObserved = true
        }

        center.post(MainActorTestNotificationMessage(payloadInt: 1, payloadString: "One"))

        center.removeObserver(token)

        #expect(notificationObserved == false)
    }

    @MainActor
    @Test func postMessageWithoutSubjectObserveNotificationWithoutObject() async throws {
        await confirmation("expected notification to be observed") { notificationObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(forName: MainActorTestNotificationMessage.name, object: nil, queue: nil) { notification in
                guard
                    notification.name == MainActorTestNotificationMessage.name
                else { return }
                
                notificationObserved()
            }
            
            center.post(MainActorTestNotificationMessage(payloadInt: 1, payloadString: "One"))
            
            center.removeObserver(token)
        }
    }

    @MainActor
    @Test func postMessageWithoutNotificationConversionAndObserveNotification() async throws {
        await confirmation("expected notification to be observed") { notificationObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(forName: nonConvertingMessageNotificationName, object: nil, queue: nil) { notification in
                guard
                    notification.name == nonConvertingMessageNotificationName,
                    notification.userInfo!.keys.count == 1,
                    notification.userInfo!.keys.contains(NotificationCenter.NotificationMessageKey.key)
                else { return }
                
                notificationObserved()
            }
            
            center.post(NonConvertingMessage())
            
            center.removeObserver(token)
        }
    }
    
    @MainActor
    @Test func postNotificationWithObjectObserveMessageWithSubject() async throws {
        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            let testSubject = MessageTestSubject()
            
            let token = center.addObserver(of: testSubject, for: .notificationMessagePosted) { message in
                if message.payloadInt == 5, message.payloadString == "Six" {
                    messageObserved()
                }
            }
            
            center.post(name: MainActorTestNotificationMessage.name, object: testSubject, userInfo: ["payloadInt": 5, "payloadString": "Six"])
            
            center.removeObserver(token)
        }
    }

    @MainActor
    @Test func postNotificationWithObjectObserveMessageWithoutSubject() async throws {
        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(of: MessageTestSubject.self, for: .notificationMessagePosted) { message in
                messageObserved()
            }
            
            let testSubject = MessageTestSubject()
            
            center.post(name: MainActorTestNotificationMessage.name, object: testSubject, userInfo: ["payloadInt": 5, "payloadString": "Six"])
            
            center.removeObserver(token)
        }
    }
    
    @MainActor
    @Test func postNotificationWithoutObjectObserveMessageWithSubject() async throws {
        let center = NotificationCenter()
        let testSubject = MessageTestSubject()
        var messageObserved = false
        
        let token = center.addObserver(of: testSubject, for: .notificationMessagePosted) { message in
            if message.payloadInt == 5, message.payloadString == "Six" {
                messageObserved = true
            }
        }
        
        center.post(name: MainActorTestNotificationMessage.name, object: nil, userInfo: ["payloadInt": 5, "payloadString": "Six"])
        
        center.removeObserver(token)

        #expect(messageObserved == false)
    }

    @MainActor
    @Test func postNotificationWithoutObjectObserveMessageWithoutSubject() async throws {
        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(of: MessageTestSubject.self, for: .notificationMessagePosted) { message in
                messageObserved()
            }
            
            center.post(name: MainActorTestNotificationMessage.name, object: nil, userInfo: ["payloadInt": 5, "payloadString": "Six"])
            
            center.removeObserver(token)
        }
    }
    
    @MainActor
    @Test func postNotificationWithoutMessageConversionAndObserveNoMessage() async throws {
        let center = NotificationCenter()
        var messageObserved = false

        let token = center.addObserver(of: MessageTestSubject.self, for: .nonConvertingMessage) { message in
            messageObserved = true
        }

        center.post(name: nonConvertingMessageNotificationName, object: nil, userInfo: nil)

        center.removeObserver(token)

        #expect(messageObserved == false)
    }
#endif
    
    // MARK: - Test different concrete Message types
    
    @MainActor
    @Test func messageAsStruct() async {
        struct MainActorStructMessage: NotificationCenter.MainActorMessage {
            typealias Subject = MessageTestSubject
            let payload: String
        }
        
        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            let subject = MessageTestSubject()

            let token = center.addObserver(of: subject, for: MainActorStructMessage.self) { message in
                if message.payload == "info" {
                    messageObserved()
                }
            }
            
            center.post(MainActorStructMessage(payload: "info"), subject: subject)
            
            center.removeObserver(token)
        }
    }
    
    @MainActor
    @Test func messageAsClass() async {
        class MainActorClassMessage: NotificationCenter.MainActorMessage {
            typealias Subject = MessageTestSubject
            let payload: String
            
            init(_ payload: String) { self.payload = payload }
        }
        
        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            let subject = MessageTestSubject()
            
            let token = center.addObserver(of: subject, for: MainActorClassMessage.self) { message in
                if message.payload == "info" {
                    messageObserved()
                }
            }
            
            center.post(MainActorClassMessage("info"), subject: subject)
            
            center.removeObserver(token)
        }
    }
    
    @MainActor
    @Test func messageAsEnum() async {
        enum BasicMessage: Int, NotificationCenter.MainActorMessage {
            typealias Subject = MessageTestSubject
            
            case first = 1, second, third, fourth
        }

        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(for: BasicMessage.self) { message in
                if message == BasicMessage.first {
                    messageObserved()
                }
            }
            
            center.post(BasicMessage(rawValue: 1)!)
            
            center.removeObserver(token)
        }
    }
    
    @MainActor
    @Test func messageAsActor() async {
        actor BasicMessage: NotificationCenter.MainActorMessage {
            typealias Subject = MessageTestSubject
            let payload: String
            
            init(_ payload: String) { self.payload = payload }
        }

        await confirmation("expected message to be observed") { messageObserved in
            let center = NotificationCenter()
            
            let token = center.addObserver(for: BasicMessage.self) { message in
                if message.payload == "info" {
                    messageObserved()
                }
            }
            
            center.post(BasicMessage("info"))
            
            center.removeObserver(token)
        }
    }

    // MARK: - ObservationToken

    @MainActor
    @Test func observationTokenRemoval() async throws {
        let center = NotificationCenter()
        var messageObserved = false
        
        let token = center.addObserver(of: MessageTestSubject.self, for: .messagePosted) { message in
            messageObserved = true
        }
        
        center.removeObserver(token)
        
        center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"))
        
        #expect(messageObserved == false)
    }

    @MainActor
    @Test func observationTokenDeinit() async throws {
        let center = NotificationCenter()
        var messageObserved = false

        do {
            let token = center.addObserver(of: MessageTestSubject.self, for: .messagePosted) { message in
                messageObserved = true
            }
            _ = token
        }

        center.post(MainActorTestMessage(payloadInt: 1, payloadString: "One"))

        #expect(messageObserved == false)
    }
    
#if FOUNDATION_FRAMEWORK
    @MainActor
    @Test func deinitDoesNotRemoveIfAlreadyRemoved() throws {
        var removeObservedCount = 0
        
        class override_removeObserver: NotificationCenter, @unchecked Sendable {
            var removeObserverHook: (() -> Void)?
            
            override func _removeObserver(_ token: UInt64) {
                removeObserverHook?()
                super._removeObserver(token)
            }
        }

        let center = override_removeObserver()
        
        center.removeObserverHook = {
            removeObservedCount += 1
        }
        
        do {
            let token = center.addObserver(of: MessageTestSubject.self, for: .messagePosted) { _ in }
            center.removeObserver(token)
        }
        
        #expect(removeObservedCount == 1)
    }
#endif

    @MainActor
    @Test func removeObserverOnlyWorksWithOriginatingCenter() throws {
        var tokenObserved = false

        let center1 = NotificationCenter()
        let center2 = NotificationCenter()
        
        let token = center1.addObserver(of: MessageTestSubject.self, for: .messagePosted) { _ in
            tokenObserved = true
        }

        center2.removeObserver(token)
        
        center1.post(MainActorTestMessage(payloadInt: 5, payloadString: "five"))
        
        #expect(tokenObserved)
        
        center1.removeObserver(token)
    }

    // MARK: - ActorQueueManager

    @Test func waitForWorkResumesOnTaskCancellation() async {
        await confirmation("expected task to end") { taskEnds in
            await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
                let state: LockedState<_NotificationCenterActorQueueManager.State> = LockedState(initialState: _NotificationCenterActorQueueManager.State())
                
                let managerTask = Task {
                    let result = await _NotificationCenterActorQueueManager.State.waitForWork(state)
                    #expect(result == nil)
                    taskEnds()
                    continuation.resume()
                }
                
                // Cancel waitForWork() once state.continuation is set
                Task {
                    while true {
                        let cancelTask = state.withLock { state in
                            return state.continuation != nil
                        }
                        if cancelTask {
                            managerTask.cancel()
                            break
                        }
                        try await Task.sleep(for: .milliseconds(50))
                    }
                }
            }
        }
    }

    @Test func waitForWorkResumesWhenTaskIsAlreadyCancelled() async {
        await confirmation("expected task to end") { taskEnds in
            await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
                let task = Task {
                    let state: LockedState<_NotificationCenterActorQueueManager.State> = LockedState(initialState: _NotificationCenterActorQueueManager.State())
                    
                    while Task.isCancelled == false {
                        do {
                            try await Task.sleep(for: .milliseconds(50))
                        } catch is CancellationError {}
                    }
                    
                    let result = await _NotificationCenterActorQueueManager.State.waitForWork(state)
                    #expect(result == nil)
                    taskEnds()
                    continuation.resume()
                }
                
                task.cancel()
            }
        }
    }
    
    // MARK: - AsyncMessageSequence
    
    @Test func makeAsyncIteratorStartsObservation() async throws {
        let sequence = NotificationCenter.default.messages(of: nil, for: AsyncTestMessage.self)

        NotificationCenter.default.post(AsyncTestMessage(payloadInt: 0, payloadString: "zero"))
        
        var iterator = sequence.makeAsyncIterator()

        NotificationCenter.default.post(AsyncTestMessage(payloadInt: 1, payloadString: "one"))
        
        let message: AsyncTestMessage? = try await iterator.next()

        // Observation begins on makeAsyncIterator(), so the first post() should be missed
        #expect(message?.payloadInt == 1)
        #expect(message?.payloadString == "one")
    }
    
    @Test func asyncMessageSequenceStopsObservationWhenDescoped() async {
        let center = NotificationCenter()
        
        #expect(center.isEmpty())

        let sequence = center.messages(of: nil, for: AsyncTestMessage.self)
        
        do {
            let iterator = sequence.makeAsyncIterator()
            _ = iterator // Suppress warning about unused 'iterator'
            #expect(!center.isEmpty())
        }
        
        #expect(center.isEmpty())
    }

    @Test func asyncMessageSequenceIteratorCopying() async throws {
        let center = NotificationCenter()
        
        let sequence = center.messages(of: nil, for: AsyncTestMessage.self)
        var iterator = sequence.makeAsyncIterator()
        var iteratorCopy = iterator

        center.post(AsyncTestMessage(payloadInt: 1, payloadString: "one"))
        
        var message = try await iterator.next()
        #expect(message?.payloadInt == 1)
        
        center.post(AsyncTestMessage(payloadInt: 2, payloadString: "two"))

        message = try await iteratorCopy.next()
        #expect(message?.payloadInt == 2)

        center.post(AsyncTestMessage(payloadInt: 3, payloadString: "three"))

        message = try await iterator.next()
        #expect(message?.payloadInt == 3)
    }
    
    @Test func asyncMessageSequenceBuffer() async throws {
        let center = NotificationCenter()
        let bufferSize = 15
        let sequence = center.messages(of: nil, for: AsyncTestMessage.self, bufferSize: bufferSize)
        var iterator = sequence.makeAsyncIterator()

        // Basic buffering
        for i in 1...5 { center.post(AsyncTestMessage(payloadInt: i, payloadString: "N/A")) }
        for i in 1...5 {
            let message = try await iterator.next()
            #expect(message?.payloadInt == i)
        }
        
        // Basic overflow handling
        for i in 1...(bufferSize + 1) { center.post(AsyncTestMessage(payloadInt: i, payloadString: "N/A")) }
        for i in 2...(bufferSize + 1) {
            let message = try await iterator.next()
            #expect(message?.payloadInt == i)
        }
    }
    
    @Test func asyncMessageSequenceDoesNotUseActorQueue() async throws {
        let center = NotificationCenter()
        let sequence = center.messages(of: nil, for: AsyncTestMessage.self)
        var iterator = sequence.makeAsyncIterator()

        // Basic buffering
        for i in 1...5 { center.post(AsyncTestMessage(payloadInt: i, payloadString: "N/A")) }

        center.asyncObserverQueue.state.withLock { _state in
            #expect(_state.buffer.isEmpty)
        }
        
        for i in 1...5 {
            let message = try await iterator.next()
            #expect(message?.payloadInt == i)
        }
    }
    
    @Test func asyncMessageSequenceMethods() async throws {
        let center = NotificationCenter()

        // messages(of: object, for: .identifier) { ... } for Subject: AnyObject
        do {
            let asyncMessageTestSubject = AsyncMessageTestSubject()
            var iterator = center.messages(of: asyncMessageTestSubject, for: .messagePosted).makeAsyncIterator()
            center.post(AsyncTestMessage(payloadInt: 1, payloadString: "N/A"), subject: asyncMessageTestSubject)
            let message = try await iterator.next()
            #expect(message?.payloadInt == 1)
        }

        // messages(of: object.Type, for: .identifier) { ... }
        do {
            var iterator = center.messages(of: AsyncMessageTestSubject.self, for: .messagePosted).makeAsyncIterator()
            center.post(AsyncTestMessage(payloadInt: 1, payloadString: "N/A"))
            let message = try await iterator.next()
            #expect(message?.payloadInt == 1)
        }
        
        // messages(of: object?, for: Message.Type) { ... } for Subject: AnyObject
        do {
            let asyncMessageTestSubject = AsyncMessageTestSubject()
            var iterator = center.messages(of: asyncMessageTestSubject, for: AsyncTestMessage.self).makeAsyncIterator()
            center.post(AsyncTestMessage(payloadInt: 1, payloadString: "N/A"), subject: asyncMessageTestSubject)
            let message = try await iterator.next()
            #expect(message?.payloadInt == 1)
        }
        do {
            var iterator = center.messages(of: nil, for: AsyncTestMessage.self).makeAsyncIterator()
            center.post(AsyncTestMessage(payloadInt: 1, payloadString: "N/A"))
            let message = try await iterator.next()
            #expect(message?.payloadInt == 1)
        }
    }
}
