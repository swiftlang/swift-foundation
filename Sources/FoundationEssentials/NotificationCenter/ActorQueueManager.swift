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
internal class _NotificationCenterActorQueueManagerNSObjectWrapper: NSObject, @unchecked Sendable {}
#else
internal class _NotificationCenterActorQueueManagerNSObjectWrapper: @unchecked Sendable {}
#endif

internal import Synchronization

#if FOUNDATION_FRAMEWORK
@objc(_NotificationCenterActorQueueManager)
#endif
internal final class _NotificationCenterActorQueueManager: _NotificationCenterActorQueueManagerNSObjectWrapper, @unchecked Sendable {
#if !NO_FILESYSTEM
    struct State {
        var buffer = [@Sendable () async -> Void]()
        var continuation: UnsafeContinuation<(@Sendable () async -> Void)?, Never>?
        var isCancelled: Bool = false
        
        static func waitForWork(_ state: borrowing Mutex<State>) async -> (@Sendable () async -> Void)? {
            return await withTaskCancellationHandler {
                return await withUnsafeContinuation { continuation in
                    let (work, resumeContinuation) = state.withLock { state -> ((@Sendable () async -> Void)?, Bool) in
                        if state.isCancelled {
                            return (nil, true)
                        } else {
                            if state.buffer.isEmpty {
                                assert(state.continuation == nil)
                                state.continuation = continuation
                                return (nil, false)
                            } else {
                                return (state.buffer.removeFirst(), true)
                            }
                        }
                    }
                    if resumeContinuation {
                        continuation.resume(returning: work)
                    }
                }
            } onCancel: {
                state.withLock { state in
                    state.isCancelled = true
                    defer {
                        state.continuation = nil
                    }
                    return state.continuation
                }?.resume(returning: nil)
            }
        }
    }
    
    let stateRef: StateReference
    let workerTask: Task<(), Never>

    final class StateReference: Sendable {
        let state: Mutex<State>

        init(_ state: consuming Mutex<State>) {
            self.state = state
        }
    }

    override init() {
        stateRef = StateReference(Mutex(State()))
        workerTask = Task.detached { [stateRef] in
            await withDiscardingTaskGroup { group in
                while let work = await State.waitForWork(stateRef.state) {
                    group.addTask(operation: work)
                }
            }
        }
        super.init()
    }
    
    deinit {
        workerTask.cancel()
    }
    
    func enqueue(_ work: @escaping @Sendable () async -> Void) {
        stateRef.state.withLock { state in
            state.buffer.append(work)
            if let continuation = state.continuation {
                state.continuation = nil
                let item = state.buffer.removeFirst()
                continuation.resume(returning: item)
            }
        }
    }
#endif
}
