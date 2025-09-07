//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
internal import CollectionsInternal
#elseif canImport(DequeModule)
internal import DequeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif
#if canImport(os)
internal import os.log
#endif

@available(FoundationPreview 6.2, *)
extension NotificationCenter {
    /// Returns an asynchronous sequence of messages produced by this center for a given subject and identifier.
    /// - Parameters:
    ///   - subject: The subject to observe. Specify a metatype to observe all values for a given type.
    ///   - identifier: An identifier representing a specific message type.
    ///   - limit: The maximum number of messages allowed to buffer.
    /// - Returns: An asynchronous sequence of messages produced by this center.
    public func messages<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject,
        for identifier: Identifier,
        bufferSize limit: Int = 10
    ) -> some AsyncSequence<Message, Never> & Sendable where Identifier.MessageType == Message, Message.Subject: AnyObject {
        return AsyncMessageSequence<Message>(self, subject, limit)
    }
    
    /// Returns an asynchronous sequence of messages produced by this center for a given subject type and identifier.
    /// - Parameters:
    ///   - subject: The metatype to observe all values for a given type.
    ///   - identifier: An identifier representing a specific message type.
    ///   - limit: The maximum number of messages allowed to buffer.
    /// - Returns: An asynchronous sequence of messages produced by this center.
    public func messages<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject.Type,
        for identifier: Identifier,
        bufferSize limit: Int = 10
    ) -> some AsyncSequence<Message, Never> & Sendable where Identifier.MessageType == Message {
        return AsyncMessageSequence<Message>(self, nil, limit)
    }
    
    /// Returns an asynchronous sequence of messages produced by this center for a given subject and message type.
    /// - Parameters:
    ///   - subject: The subject to observe. Specify a metatype to observe all values for a given type.
    ///   - messageType: The message type to be observed.
    ///   - limit: The maximum number of messages allowed to buffer.
    /// - Returns: An asynchronous sequence of messages produced by this center.
    public func messages<Message: AsyncMessage>(
        of subject: Message.Subject? = nil,
        for messageType: Message.Type,
        bufferSize limit: Int = 10
    ) -> some AsyncSequence<Message, Never> & Sendable where Message.Subject: AnyObject {
        return AsyncMessageSequence<Message>(self, subject, limit)
    }
}

extension NotificationCenter {
    fileprivate struct AsyncMessageSequence<Message: NotificationCenter.AsyncMessage>: AsyncSequence, Sendable {
        let center: NotificationCenter
        nonisolated(unsafe) weak var object: AnyObject?
        let bufferSize: Int
        
        init(_ center: NotificationCenter, _ object: AnyObject?, _ bufferSize: Int) {
            self.center = center
            self.object = object
            self.bufferSize = bufferSize
        }
        
        func makeAsyncIterator() -> AsyncMessageSequenceIterator<Message> {
            return AsyncMessageSequenceIterator(center: center, object: object, bufferSize: bufferSize)
        }
    }
}

extension NotificationCenter {
    fileprivate final class AsyncMessageSequenceIterator<Message: NotificationCenter.AsyncMessage>: AsyncIteratorProtocol, Sendable {
        typealias Element = Message
        typealias Failure = Never
        
        struct State {
            var observer: NotificationCenter.ObservationToken?
            var continuations: [UnsafeContinuation<Message?, Never>] = []
            var buffer = Deque<Message>(minimumCapacity: 1)
            let bufferSize: Int
        }
        
        struct Resumption {
            let message: Message?
            let continuations: [UnsafeContinuation<Message?, Never>]
            
            init(message: Message?, continuation: UnsafeContinuation<Message?, Never>) {
                self.message = message
                self.continuations = [continuation]
            }
            
            init(cancelling: [UnsafeContinuation<Message?, Never>]) {
                self.message = nil
                self.continuations = cancelling
            }
            
            func resume() {
                for continuation in continuations {
                    continuation.resume(returning: message)
                }
            }
        }
        
        let state: LockedState<State>
        
        init(center: NotificationCenter, object: AnyObject?, bufferSize: Int) {
            self.state = LockedState(initialState: State(bufferSize: bufferSize))
            
#if FOUNDATION_FRAMEWORK
            let observerBlock: @Sendable (Notification) -> Void =  { [weak self] notification in
                guard let message: Message = NotificationCenter._messageFromNotification(notification) else { return }
                
                self?.observationCallback(message)
            }
#else
            let observerBlock: @Sendable (Message) -> Void =  { [weak self] message in
                self?.observationCallback(message)
            }
#endif
            
            let token = center._addObserver(Message.name, object: object, using: observerBlock)

            self.state.withLock { _state in
                _state.observer = ObservationToken(center: center, token: token)
            }
        }
        
        deinit {
            teardown()
        }

        func teardown() {
            let (observer, resumption) = state.withLock { _state -> (NotificationCenter.ObservationToken?, Resumption) in
                let observer = _state.observer
                _state.observer = nil
                _state.buffer.removeAll(keepingCapacity: false)
                defer { _state.continuations.removeAll(keepingCapacity: false) }
                return (observer, Resumption(cancelling: _state.continuations))
            }
            
            resumption.resume()
            
            if let observer {
                observer.remove()
            }
        }
        
        func observationCallback(_ message: Message) {
            state.withLock { _state -> Resumption? in
                if _state.buffer.count + 1 > _state.bufferSize {
                    _state.buffer.removeFirst()
#if canImport(os)
                    NotificationCenter.logger.fault("Notification center message dropped due to buffer limit. Check sequence iterator frequently or increase buffer size. Message: \(String(describing: Message.self))")
#endif
                }
                _state.buffer.append(message)
                
                if _state.continuations.isEmpty {
                    return nil
                } else {
                    return Resumption(message: _state.buffer.removeFirst(), continuation: _state.continuations.removeFirst())
                }
            }?.resume()
        }
        
        func next() async -> Message? {
            await withTaskCancellationHandler {
                return await withUnsafeContinuation { (continuation: UnsafeContinuation<Message?, Never>) in
                    state.withLock { _state -> Resumption? in
                        _state.continuations.append(continuation)
                        if _state.buffer.isEmpty {
                            return nil
                        } else {
                            return Resumption(message: _state.buffer.removeFirst(), continuation: _state.continuations.removeFirst())
                        }
                    }?.resume()
                }
            } onCancel: {
                teardown()
            }
        }
    }
}
