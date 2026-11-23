//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// `NotificationRegistrar` is not yet available for embedded.
#if !hasFeature(Embedded)

/// NotificationRegistrar is the core of NotificationCenter, storing registrations and calling them with notifications based on posted parameters.
///
/// It has a few moving parts:
/// 
/// **Registration**: Each addObserver() call creates a registration, storing the: handler to call (a block, a selector, or a C function), index of the observer object (if any), index of the registered name, and object (if any).
/// **NameTable**: Stores distinct, registered notification names.
/// **NameAndObjectTable**: Stores (name, object) pairs, de-duped across registrations.
/// **ObserverTable**: Observer object reference storage, de-duped across multiple registrations, with StableStorage to ensure weak pointers are never moved during registrar growth. These may be shared across many registrations. BlockObservers (created by an addObserver variant with no 'observer' parameter) are also stored here.
/// **RegistrationFilter**: Collection of bloom filters and flags used to quickly return from post() when there are no relevant registrations
/// **DeliveryCollector**: Used by post to store registration callbacks that need to be called for a given post. Notification postings are re-entrant so each notification delivery must be copied to be used outside the registrar lock.

internal import Synchronization

// MARK: - Typealiases

// These typealiases exist to support a variety of compilation targets and improve readability.

typealias UnsafeObjectPtr = UnsafeRawPointer
#if FOUNDATION_FRAMEWORK
typealias NotificationType = NSNotification
typealias RegistrarStringType = NSString
typealias ObserverBlock = @convention(block) @Sendable (NotificationType) -> Void
typealias RawCFNotificationCallback = @convention(c) (UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?, UnsafeRawPointer?) -> Void
#if NO_FILESYSTEM
typealias ObserverQueue = Never
#else
typealias ObserverQueue = OperationQueue
#endif
#else
typealias NotificationType = Notification
typealias RegistrarStringType = String
typealias ObserverBlock = @Sendable (NotificationType) -> Void
typealias ObserverQueue = Never
#endif

// MARK: - Helpers

fileprivate extension UnsafeRawPointer {
    init(_ object: AnyObject) {
        self = UnsafeRawPointer(Unmanaged.passUnretained(object).toOpaque())
    }
    
    init?(_ object: AnyObject?) {
        if let object {
            self = UnsafeRawPointer(Unmanaged.passUnretained(object).toOpaque())
        } else {
            return nil
        }
    }
}

enum PostedObject {
    case object(Unmanaged<AnyObject>)  // NS posts, uses Unmanaged to avoid unnecessary retain/releases
    case pointer(UnsafeRawPointer)     // CF posts, any pointer, not necessarily an object
    
    var pointer: UnsafeObjectPtr {
        switch self {
        case .object(let object): UnsafeRawPointer(object.toOpaque())
        case .pointer(let pointer): pointer
        }
    }
}

// MARK: - NotificationRegistrar

// Main interface backing the public API. Called into by bridging classes.
internal final class NotificationRegistrar: Sendable {
    private let registrationFilter: RegistrationFilter // outside state, explicitly does not take the lock
    private let state: Mutex<State>
    
    init() {
        state = .init(State())
        registrationFilter = .init()
    }
    
    // Register by name, object, queue, and block, returning an object (e.g. NSNotificationCenter)
    func addObserver(nameHash: Int?, name: RegistrarStringType?, object: UnsafeObjectPtr?, queue: ObserverQueue?, using block: @escaping ObserverBlock) -> BlockObserver {
        return withAddObserverLock { _state in
            let observer = BlockObserver(token: _state.registrations.nextToken)
            _ = Unmanaged.passUnretained(observer).retain()

            let entry = _state.observers.entry(for: UnsafeRawPointer(observer)).index
            
            let token = _state.register(.closure(block, queue), nameHash: nameHash, name: name, object: object, observerEntry: entry, registrationFilter)
            assert(token == observer.token, "register should return the same token BlockObserver used")

            return observer
        }
    }
    
    // Register by name, object, and block, returning a token (e.g. NotificationCenter.Message backing)
    func addObserver(nameHash: Int?, name: RegistrarStringType?, object: UnsafeObjectPtr?, using block: @escaping ObserverBlock) -> Token {
        return withAddObserverLock { _state in
            _state.register(.closure(block, nil), nameHash: nameHash, name: name, object: object, observerEntry: .noEntry, registrationFilter)
        }
    }
    
#if FOUNDATION_FRAMEWORK
    // Register by observer object, selector, and object (e.g. NSNotificationCenter selector adds)
    func addObserver(_ observer: AnyObject, selector: Selector, weak: Bool, nameHash: Int?, name: RegistrarStringType?, object: UnsafeObjectPtr?) -> Token {
        let observerPtr = UnsafeRawPointer(observer)
        
        // Release the loaded observer outside the lock to avoid reentrancy issues
        let (token, _) = withAddObserverLock { _state -> (Token, AnyObject?) in
            if weak {
                let (entry, loaded) = _state.weakEntry(observerPtr, observer, registrationFilter)
                return (_state.register(.selector(selector, .weak(_state.observers.pointer(entry))), nameHash: nameHash, name: name, object: object, observerEntry: entry, registrationFilter), consume loaded)
            }
            
            let entry = _state.observers.entry(for: observerPtr).index
            return (_state.register(.selector(selector, .raw(observerPtr)), nameHash: nameHash, name: name, object: object, observerEntry: entry, registrationFilter), nil)
        }
        return token
    }
    
    // Register by unsafe observer pointer, name, and object (e.g. CFNotificationCenter)
    func addObserver(_ observerPtr: UnsafeRawPointer?, callbackObserver: UnsafeRawPointer?, weakObserver: AnyObject?, callback: CFNotificationCallback, center: UnsafeRawPointer, nameHash: Int?, name: RegistrarStringType?, object: UnsafeObjectPtr?) -> Token {
        // Release the loaded observer outside the lock to avoid reentrancy issues
        let (token, _) = withAddObserverLock { _state -> (Token, AnyObject?) in
            var entry = ObserverTable.Index.noEntry
            var reference = Registration.Handler.Observer.raw(callbackObserver)
            var loaded: AnyObject?
            
            if let observerPtr {
                if let weakObserver {
                    (entry, loaded) = _state.weakEntry(observerPtr, weakObserver, registrationFilter)
                    reference = .weak(_state.observers.pointer(entry))
                } else {
                    entry = _state.observers.entry(for: observerPtr).index
                }
            }
            
            precondition(_state.cfCenter == nil || _state.cfCenter == center, "A registrar belongs to only one CF center")
            _state.cfCenter = center
            let handler = Registration.Handler.function(unsafeBitCast(callback, to: RawCFNotificationCallback.self), observer: reference)
            
            return (_state.register(handler, nameHash: nameHash, name: name, object: object, observerEntry: entry, registrationFilter), consume loaded)
        }
        return token
    }
#endif
    
    @inline(__always) private func withAddObserverLock<Result>(_ body: (inout State) -> Result) -> Result {
        let (result, sweepIsDue) = state.withLock { _state in (body(&_state), _state.sweepIsDue) }
        if sweepIsDue { sweepExpiredWeak() }
        return result
    }
    
    func post(nameHash: Int, name: RegistrarStringType,  object: PostedObject?, userInfo: AnyObject? = nil, makeNotification: () -> NotificationType) {
        
        // Hot path - exit early if no one is observing this name, or this object with a nil name
        if registrationFilter.rejects(nameHash: nameHash, object: object) { return }
        
        withUnsafeTemporaryAllocation(of: DeliveryCollector.Delivery.self, capacity: 16) { stack in
            var collector = DeliveryCollector(stack: stack)
            
            state.withLock { _state in
                var expiredTokens: [Token] = []
                let objectKey = object?.pointer
                
                func collect(_ list: SlotMapList<Registration.NameAndObjectLinkage>) {
                    var index = list.head
                    
                    while index != .noIndex {
                        let token = _state.registrations.token(at: index)
                        
                        if let delivery = DeliveryCollector.Delivery(_state.registrations[index: index].handler, token, cfCenter: _state.cfCenter) {
                            collector.append(delivery)
                        } else {
                            expiredTokens.append(token) // weak observer was released
                        }
                        
                        index = _state.registrations.next(after: index, in: list)
                    }
                }
                
                func collect(_ nameIndex: NameTable.Index) {
                    collect(_state.names[nameIndex].anyObjectRegistrations)
                    if let objectKey, _state.names[nameIndex].objectRegistrationCount != 0,
                       let index = _state.nameAndObjects.find(nameIndex, objectKey) {
                        collect(_state.nameAndObjects[index].registrations)
                    }
                }
                
                if let nameIndex = _state.names.find(NameTable.Key(hash: nameHash, name: name)) { collect(nameIndex) }
                if _state.names[.anyNameIndex].registrationCount != 0 { collect(.anyNameIndex) }
                
                for token in expiredTokens {
                    _state.remove(token, registrationFilter)
                }
            }
            
            guard collector.count > 0 else { return }
            
            // Retain self as an observer could dealloc this registrar
            let keepAlive = Unmanaged.passUnretained(self).retain()
            defer { keepAlive.release() }
            
            // Retain userInfo in case an observer releases it
            let userInfoKeepAlive = userInfo.map { Unmanaged.passUnretained($0).retain() }
            defer { userInfoKeepAlive?.release() }
            
            // Retain object in case an observer releases it
            var objectKeepAlive: Unmanaged<AnyObject>?
            if case .object(let object) = object { objectKeepAlive = object.retain() }
            defer { objectKeepAlive?.release() }

#if FOUNDATION_FRAMEWORK
            let nameKeepAlive = Unmanaged.passUnretained(name).retain()
            defer { nameKeepAlive.release() }
#endif
            
            var cachedNotification: NotificationType?
            func notification() -> NotificationType {
                if let cachedNotification { return cachedNotification }
                let n = makeNotification()
                cachedNotification = n
                return n
            }

#if FOUNDATION_FRAMEWORK && !NO_FILESYSTEM
            var asyncOps: [Operation] = []
#endif
            collector.sortedForEach { (delivery: borrowing DeliveryCollector.Delivery) in
#if FOUNDATION_FRAMEWORK && !NO_FILESYSTEM
                // If the callback requires a different queue than the current one, enqueue it. Enqueued callbacks will run async but post() will wait until they all finish per API contract.
                if let queue = delivery.queue, queue !== OperationQueue.current, !(pthread_main_np() == 1 && OperationQueue.main === queue) {
                    nonisolated(unsafe) let note = notification(), handler = delivery.handler, name = name, object = object, userInfo = userInfo
                    let token = delivery.token
                    let op: Operation = BlockOperation { [self] in
                        // Re-validate token in case observer was removed
                        guard self.state.withLock({ $0.registrations.contains(token) }) else { return }
                        callOutToObserver(handler, name: name, object: object?.pointer, userInfo: userInfo, notification: note)
                    }
                    queue.addOperation(op)
                    asyncOps.append(op)
                    return
                }
#endif
                // Re-validate token in case observer was removed
                let token = delivery.token
                guard self.state.withLock({ $0.registrations.contains(token) }) else { return }
                callOutToObserver(delivery.handler, name: name, object: object?.pointer, userInfo: userInfo, notification: delivery.handler.needsNotificationBuilt ? notification() : nil)
            }
#if FOUNDATION_FRAMEWORK && !NO_FILESYSTEM
            for op in asyncOps { op.waitUntilFinished() }
#endif
        }
    }

    func removeObserver(_ token: Token) {
        // Release the removed registration outside the lock to avoid reentrancy issues
        _ = state.withLock { _state in
            _state.remove(token, registrationFilter)
        }
    }
    
    func removeObserver(_ observer: AnyObject, name: RegistrarStringType?, object: UnsafeObjectPtr?) {
        removeObserver(UnsafeRawPointer(observer), name: name, object: object)
    }
    
    func removeObserver(_ observerPtr: UnsafeRawPointer, name: RegistrarStringType?, object: UnsafeObjectPtr?) {
        struct Disposal: ~Copyable {
            var s0: State.Removal?
            var s1: State.Removal?
            var overflow: [State.Removal]?

            mutating func add(_ r: State.Removal) {
                if s0 == nil { s0 = r }
                else if s1 == nil { s1 = r }
                else if overflow == nil { overflow = [r] }
                else { overflow!.append(r) }
            }
        }
        
        // Return `Disposal` to ARC release happens outside the lock to avoid reentrancy issues
        _ = state.withLock { _state -> Disposal in
            var disposal = Disposal()
            
            guard let entry = _state.observers.find(observerPtr) else { return disposal }
            
            var current = _state.observers[entry].registrations.head
            while current != .noIndex {
                let next = _state.registrations.next(after: current, in: _state.observers[entry].registrations)
                var matches = true
                
                if let name {
                    let registeredName = _state.names[_state.registrations[index: current].nameIndex].name?.name
#if FOUNDATION_FRAMEWORK
                    if registeredName !== name && registeredName != name { matches = false }
#else
                    if registeredName != name { matches = false }
#endif
                }
                
                // A specific name or object only removes registrations for exactly that name or object, not the wildcard ones
                if matches, let object, _state.registrations[index: current].object != object { matches = false }
                
                if matches, let removed = _state.remove(_state.registrations.token(at: current), retireEmptyEntry: false, registrationFilter) {
                    disposal.add(removed)
                }

                current = next
            }
            
            if _state.observers[entry].registrations.isEmpty { _state.observers.remove(entry) }
            
            return disposal
        }
    }
    
    func isEmpty() -> Bool {
        return state.withLock { $0.registrations.isEmpty }
    }
    
    func debugInfo() -> String {
#if FOUNDATION_FRAMEWORK
        func symbol(_ callback: RawCFNotificationCallback) -> String {
            let ptr = unsafeBitCast(callback, to: UnsafeRawPointer.self)
#if !NO_FILESYSTEM
            var info = Dl_info()
            if dladdr(ptr, &info) != 0, let sname = info.dli_sname { return "\(String(cString: sname)) (\(ptr))" }
#endif
            return "\(ptr)"
        }
#endif
        
        return state.withLock { _state in
            var desc = ""
            
            _state.registrations.forEach { token, r in
                let observer: UnsafeRawPointer?
                let handler: String
                
                switch r.handler {
                case .closure:
                    observer = nil
                    handler = "block"
#if FOUNDATION_FRAMEWORK
                case .selector(let selector, _):
                    observer = r.observerEntry == .noEntry ? nil : _state.observers[r.observerEntry].address
                    handler = "selector = \(selector)"
                case .function(let callback, let reference):
                    if case .raw(let pointer) = reference { observer = pointer } else { observer = _state.observers[r.observerEntry].address }
                    handler = "callback = \(symbol(callback))"
#endif
                }
                
                desc += "{\n"
                desc += "    token = \(String(token.rawValue, radix: 16))\n"
                desc += "    name = \(_state.names[r.nameIndex].name.map { "\($0.name)" } ?? "kCFNotificationAnyName")\n"
                desc += "    object = \(r.object.map { "\($0)" } ?? "kCFNotificationAnyObject")\n"
                desc += "    observer = \(observer.map { "\($0)" } ?? "0x0" )\n"
                desc += "    \(handler)\n"
                desc += "}\n"
            }
            
            return desc
        }
    }
    
    func convertToToken(_ block: BlockObserver) -> Token {
        _ = state.withLock {
            $0.convertToToken(block.token)
        }
        
        return block.token
    }
    
    // For testing only
    internal var _observerCount: Int {
        state.withLock { $0.registrations.count }
    }
    
    // For testing only
    internal func _forceSweepExpiredWeak() {
        let _ = state.withLock { $0.sweepExpiredWeak(registrationFilter) }
    }
    
    // For testing only
    internal func _forceFilterRebuild() {
        state.withLock { _state in
            registrationFilter.rebuildNames(_state.names.hashes)
            registrationFilter.rebuildNilNameObjects(_state.nameAndObjects.nilNameObjects)
        }
    }
    
    @inline(never) private func sweepExpiredWeak() {
        _ = state.withLock { _state in _state.sweepIsDue ? _state.sweepExpiredWeak(registrationFilter) : [] }
    }
    
    private struct State: ~Copyable, @unchecked Sendable {
        // All observer registrations, one per addObserver() call
        var registrations = SlotMap(vacant: Registration.vacant)
        // All registered names, de-duped
        var names = NameTable()
        // All registered (name, object) pairs, de-duped
        var nameAndObjects = NameAndObjectTable()
        // All registered observers, de-duped
        var observers = ObserverTable()
        // The CF center associated with this registrar
        var cfCenter: UnsafeRawPointer? = nil
        // Capacity at last sweep
        var sweptAtCapacity = 0
        // Sweep is due when registrations' capacity doubles
        var sweepIsDue: Bool { registrations.capacity >= 2 * sweptAtCapacity }
        
        deinit {
            // Any block registrations still active need their BlockObservers released
            registrations.forEach { _, r in
                if case .closure = r.handler, r.observerEntry != .noEntry {
                    releaseBlockObserver(at: r.observerEntry)
                }
            }
        }
        
        // A removed registration and its BlockObserver, if any
        typealias Removal = (registration: Registration, blockObserver: BlockObserver?)
        
        // Removes a registration from the map and updates the name, object and observer bookkeeping
        @discardableResult
        mutating func remove(_ token: Token, retireEmptyEntry: Bool = true, _ registrationFilter: borrowing RegistrationFilter) -> Removal? {
            guard let removed = registrations.remove(token) else { return nil }
            
            unlinkFromNameAndObject(removed, registrationFilter)
            let blockObserver = unlinkFromObserver(removed, retireEmptyEntry: retireEmptyEntry)
            
            return (removed, blockObserver)
        }
        
        // Undo name, object, and other bookkeeping associated with `removed`
        private mutating func unlinkFromNameAndObject(_ removed: Registration, _ registrationFilter: borrowing RegistrationFilter) {
            let nameIndex = removed.nameIndex
            
            if let object = removed.object {
                if let index = nameAndObjects.find(nameIndex, object) {
                    registrations.unlink(removed, from: &nameAndObjects[index].registrations)
                    
                    if nameAndObjects[index].registrations.isEmpty {
                        nameAndObjects.remove(index)
                        
                        if nameIndex == .anyNameIndex && registrationFilter.nilNameObjectsAreStale(liveCount: nameAndObjects.nilNameCount) {
                            registrationFilter.rebuildNilNameObjects(nameAndObjects.nilNameObjects)
                        }
                    }
                }
                
                names[nameIndex].objectRegistrationCount -= 1
            } else {
                registrations.unlink(removed, from: &names[nameIndex].anyObjectRegistrations)
                
                if nameIndex == .anyNameIndex && names[nameIndex].anyObjectRegistrations.isEmpty {
                    registrationFilter.setWildcardIsEmpty(true)
                }
            }
            
            names[nameIndex].registrationCount -= 1

            if names[nameIndex].registrationCount == 0 && nameIndex != .anyNameIndex {
                names.remove(nameIndex)
            }
            
            if registrationFilter.namesAreStale(liveCount: names.count) {
                registrationFilter.rebuildNames(names.hashes)
            }
        }
        
        // Undo observer bookkeeping associated with `registration`, returning its BlockObserver, if any
        private mutating func unlinkFromObserver(_ registration: Registration, retireEmptyEntry: Bool = true) -> BlockObserver? {
            let entry = registration.observerEntry
            
            guard entry != .noEntry else { return nil }

            registrations.unlink(registration, from: &observers[entry].registrations)

            var blockObserver: BlockObserver?
            if case .closure = registration.handler {
                blockObserver = takeBlockObserver(at: entry)
            }
            if retireEmptyEntry && observers[entry].registrations.isEmpty {
                observers.remove(entry)
            }
            return blockObserver
        }
        
        // Foundation routes token-only, subclassed addObserver calls through the BlockObserver methods to avoid breaking subclasses. This method converts them back to token-only as intended.
        mutating func convertToToken(_ token: Token) -> BlockObserver? {
            guard registrations.contains(token) else { return nil }
            
            let registration = registrations[index: token.index]
            
            let blockObserver = unlinkFromObserver(registration)
            
            registrations[index: token.index].observerEntry = .noEntry
            
            return blockObserver
        }
        
        private func takeBlockObserver(at entry: ObserverTable.Index) -> BlockObserver {
            Unmanaged<BlockObserver>.fromOpaque(observers[entry].address!).takeRetainedValue()
        }
        
        private func releaseBlockObserver(at entry: ObserverTable.Index) {
            Unmanaged<BlockObserver>.fromOpaque(observers[entry].address!).release()
        }
        
#if FOUNDATION_FRAMEWORK
        // Finds or creates the entry for a weak observer, removing registrations of deallocated observers at the same address, if any. Returns the observer if it was already registered, to be released outside the lock.
        mutating func weakEntry(_ observerPtr: UnsafeRawPointer, _ observer: AnyObject, _ registrationFilter: borrowing RegistrationFilter) -> (index: ObserverTable.Index, loaded: AnyObject?) {
            let (entry, isNew) = observers.entry(for: observerPtr)
            let p = observers.pointer(entry)

            let loaded = p.pointee.weakObserver
            guard loaded == nil else { return (entry, consume loaded) }

            if !isNew {
                var current = observers[entry].registrations.head
                
                while current != .noIndex {
                    let next = registrations.next(after: current, in: observers[entry].registrations)
                    
                    switch registrations[index: current].handler {
                    case .selector(_, .weak(p)), .function(_, observer: .weak(p)):
                        remove(registrations.token(at: current), retireEmptyEntry: false, registrationFilter)
                    default: break
                    }
                    
                    current = next
                }
            }
            
            // Note this weak assignment expects the caller to have ensured +initialize already ran (avoids deadlocks / reentrancy issues)
            p.pointee.weakObserver = observer
            
            return (entry, nil)
        }
#endif
        
        // Removes registrations where a weak observer is already deallocated, returning any loaded observers to be released after unlocking
        mutating func sweepExpiredWeak(_ registrationFilter: borrowing RegistrationFilter) -> ContiguousArray<AnyObject> {
            var loaded: ContiguousArray<AnyObject> = []
            
            sweptAtCapacity = registrations.capacity
            
            // Only Foundation.framework registers weak observers
#if FOUNDATION_FRAMEWORK
            var expiredTokens: [Token] = []
            
            registrations.forEach { token, r in
                switch r.handler {
                case .selector(_, .weak(let entry)),
                     .function(_, observer: .weak(let entry)):
                    if let observer = entry.pointee.weakObserver {
                        loaded.append(consume observer)
                    } else {
                        expiredTokens.append(token)
                    }
                default: break
                }
            }
            
            for token in expiredTokens {
                remove(token, registrationFilter)
            }
#endif
            return loaded
        }
        
        /// Stores a registration, handling any required name, object, observer, and filter entries
        mutating func register(_ handler: Registration.Handler, nameHash: Int?, name: RegistrarStringType?, object: UnsafeObjectPtr?, observerEntry: ObserverTable.Index, _ registrationFilter: borrowing RegistrationFilter) -> Token {
            let nameIndex: NameTable.Index
            
            // Find or create name entry
            if let nameHash, let name {
                let (index, isNew) = names.entry(for: NameTable.Key(hash: nameHash, name: name))
                nameIndex = index
                if isNew { registrationFilter.insertName(hash: nameHash) }
            } else {
                nameIndex = .anyNameIndex
                if object == nil && names[nameIndex].anyObjectRegistrations.isEmpty {
                    registrationFilter.setWildcardIsEmpty(false)
                }
            }
            
            // Store the registration
            let insertToken = registrations.insert(Registration(handler: handler, nameIndex: nameIndex, object: object, observerEntry: observerEntry))

            // Link to the observer table
            if observerEntry != .noEntry {
                registrations.link(insertToken.index, into: &observers[observerEntry].registrations)
            }
            
            // Link to the nameAndObjects table
            if let object {
                let (index, isNew) = nameAndObjects.entry(for: nameIndex, object)
                
                if isNew && nameIndex == .anyNameIndex {
                    registrationFilter.insertNilNameObject(object)
                }
                
                registrations.link(insertToken.index, into: &nameAndObjects[index].registrations)
                names[nameIndex].objectRegistrationCount += 1
            } else {
                registrations.link(insertToken.index, into: &names[nameIndex].anyObjectRegistrations)
            }
            names[nameIndex].registrationCount += 1
            
            return insertToken
        }
    }
}

extension NotificationRegistrar {
    // Process-wide local registrar
    static let local = NotificationRegistrar()
}

// MARK: - Registration

/// `Registration` is the record stored when addObserver() is called.
/// 
/// `Registration` ties the callback handler with the appropriate name, object, and observer entries.
fileprivate struct Registration {
    let handler: Handler

    // nameIndex is 24 bits to save on memory
    private let nameIndexLow: UInt8
    private let nameIndexHigh: UInt16

    // Caution: this field layout was chosen to keep `Registration` small
    var nameAndObjectLinks = SlotListLinkPair()
    var observerEntry: ObserverTable.Index
    let object: UnsafeObjectPtr?
    var observerLinks = SlotListLinkPair()
    
    init(handler: Handler, nameIndex: NameTable.Index, object: UnsafeObjectPtr?, observerEntry: ObserverTable.Index) {
        self.handler = handler
        self.nameIndexLow = nameIndex.low
        self.nameIndexHigh = nameIndex.high
        self.observerEntry = observerEntry
        self.object = object
    }
    
    var nameIndex: NameTable.Index {
        NameTable.Index(low: nameIndexLow, high: nameIndexHigh)
    }
    
    static var vacant: Registration {
        Registration(handler: .closure({ _ in }, nil), nameIndex: .anyNameIndex, object: nil, observerEntry: .noEntry)
    }
    
    fileprivate enum Handler {
        case closure(ObserverBlock, ObserverQueue?)
    #if FOUNDATION_FRAMEWORK
        case selector(Selector, Observer) // selector first saves on the memory layout
        case function(RawCFNotificationCallback, observer: Observer)
    #endif
        
        #if FOUNDATION_FRAMEWORK
        fileprivate enum Observer {
            case weak(UnsafeMutablePointer<ObserverTable.Entry>)
            case raw(UnsafeRawPointer?)
        }
        #endif
    }
    
    fileprivate enum ObserverLinkage: SlotListLinkage {
        static var linkPair: WritableKeyPath<Registration, SlotListLinkPair> { \.observerLinks }
    }
    
    fileprivate enum NameAndObjectLinkage: SlotListLinkage {
        static var linkPair: WritableKeyPath<Registration, SlotListLinkPair> { \.nameAndObjectLinks }
    }
}

// MARK: - ObserverTable

/// Fast index for observer objects, used to tie the same observer to multiple registrations.
/// Designed to avoid moving weak observer references on growth by using StableStorage.
fileprivate struct ObserverTable: IntrusiveHashTable, ~Copyable {
    typealias Index = StableStorage<Entry>.Index

    private var entries = StableStorage(vacant: Entry())
    var heads: ContiguousArray<Index> = []
    var count = 0
    static let maxLoad: Int = 2
    
    func pointer(_ entry: Index) -> UnsafeMutablePointer<Entry> { entries.pointer(entry) }
    
    // Address directly to avoid copying the weak reference
    subscript(_ entry: Index) -> Entry {
        unsafeAddress { UnsafePointer(entries.pointer(entry)) }
        unsafeMutableAddress { entries.pointer(entry) }
    }
    
    func key(at index: Index) -> UnsafeRawPointer { entries.pointer(index).pointee.address! }
    
    subscript(next index: Index) -> Index {
        get { entries.pointer(index).pointee.next }
        set { entries.pointer(index).pointee.next = newValue }
    }
    
    /// Find or create the entry for `key`
    mutating func entry(for key: UnsafeRawPointer) -> (index: Index, isNew: Bool) {
        if let n = find(key) { return (n, false) }
        
        let n = entries.allocate()
        precondition(n.rawValue < Index.noEntry.rawValue, "ObserverTable entry numbers must stay below noEntry")
        
        self[n].address = key
        link(n)
        
        return (n, true)
    }
    
    mutating func remove(_ entry: Index) {
        unlink(entry)
        
        // Clear the StableStorage entry so it's safe to reuse
        self[entry].weakObserver = nil
        self[entry].address = nil
        self[entry].registrations = SlotMapList()
        self[entry].next = .noEntry
        
        entries.free(entry)
    }
    
    struct Entry: IntrusiveHashEntry {
        static func hash(_ key: UnsafeRawPointer) -> UInt64 { UInt64(UInt(bitPattern: key)) }
        
        weak var weakObserver: AnyObject?
        var address: UnsafeRawPointer? = nil
        var registrations = SlotMapList<Registration.ObserverLinkage>()
        var next: Index = .noEntry
    }
}

fileprivate extension StableStorage.Index where Element == ObserverTable.Entry {
    static var noEntry: Self { ObserverTable.end }
}

// `BlockObserver` wraps `Token` to meet addObserver() API expectations
internal final class BlockObserver: Sendable {
    fileprivate let token: Token
    
    init(token: Token) {
        self.token = token
    }
}

// MARK: - NameTable

// Stores distinct, registered names as well as the wildcard name.
fileprivate struct NameTable: IntrusiveHashTable {
    private var entries: ContiguousArray<Entry> = [Entry()]
    private var free: ContiguousArray<Index> = []
    var heads: ContiguousArray<Index> = []
    var count = 0 // excluding the wildcard
    static let maxLoad: Int = 1
    
    var hashes: some Sequence<Int> { entries.lazy.compactMap { $0.name?.hash } }
    
    subscript(_ index: Index) -> Entry {
        get { entries[index] }
        _modify { yield &entries[index] }
    }
    
    func key(at index: Index) -> Key { entries[index].name! }
    
    subscript(next index: Index) -> Index {
        get { entries[index].next }
        set { entries[index].next = newValue }
    }
    
    /// Find or create the entry for `key`
    mutating func entry(for key: Key) -> (index: Index, isNew: Bool) {
        if let index = find(key) { return (index, false) }
        
#if FOUNDATION_FRAMEWORK
        // When RegistrarStringType is NSString, copy 'name' to prevent issues from a later string mutation
        let key = Key(hash: key.hash, name: key.name.copy() as! NSString)
#endif

        let index: Index
        if let reused = free.popLast() {
            index = reused
            entries[index] = Entry(name: key)
        } else {
            precondition(entries.count < Index.capacity, "Name index should be 24 bits")
            
            index = Index(rawValue: UInt32(entries.count))
            entries.append(Entry(name: key))
        }
        
        link(index)
        
        return (index, true)
    }
    
    mutating func remove(_ index: Index) {
        unlink(index)
        entries[index] = Entry()
        free.append(index)
    }
    
    struct Index: RawRepresentable, Equatable {
        let rawValue: UInt32
        
        static var anyNameIndex: Index { Index(rawValue: 0) }
        static let capacity: Int = 1 << 24 // Name index is 24 bit
        
        var low: UInt8 { UInt8(truncatingIfNeeded: rawValue) }
        var high: UInt16 { UInt16(truncatingIfNeeded: rawValue >> 8) }
        
        init(rawValue: UInt32) { self.rawValue = rawValue }
        init(low: UInt8, high: UInt16) { rawValue = UInt32(low) | UInt32(high) << 8 }
    }
    
    struct Key: Equatable {
        let hash: Int
        let name: RegistrarStringType
        
        @inline(__always)
        static func == (l: Key, r: Key) -> Bool {
            guard l.hash == r.hash else { return false }
#if FOUNDATION_FRAMEWORK
            // NSString here, so compare object identity
            if l.name === r.name { return true }
#endif
            return l.name == r.name
        }
    }
    
    struct Entry: IntrusiveHashEntry {
        static func hash(_ key: Key) -> UInt64 { UInt64(UInt(bitPattern: key.hash)) }
        
        var name: Key? = nil
        var next: Index = NameTable.end
        var registrationCount: UInt32 = 0
        var anyObjectRegistrations = SlotMapList<Registration.NameAndObjectLinkage>()
        var objectRegistrationCount: UInt32 = 0
    }
}

fileprivate extension ContiguousArray<NameTable.Entry> {
    subscript(_ index: NameTable.Index) -> NameTable.Entry {
        get { self[Int(index.rawValue)] }
        _modify { yield &self[Int(index.rawValue)] }
    }
}

// MARK: - NameAndObjectTable

// The (name, object) pairs with registrations for a specific object
fileprivate struct NameAndObjectTable: IntrusiveHashTable {
    private var entries: ContiguousArray<Entry> = []
    private var free: ContiguousArray<Index> = []
    var heads: ContiguousArray<Index> = []
    var count = 0
    static let maxLoad: Int = 1
    private(set) var nilNameCount = 0
    
    var nilNameObjects: some Sequence<UnsafeObjectPtr> {
        entries.lazy.compactMap { $0.nameIndex == .anyNameIndex ? $0.object : nil }
    }
    
    subscript(_ index: Index) -> Entry {
        get { entries[index] }
        _modify { yield &entries[index] }
    }
    
    func key(at index: Index) -> Key { Key(object: entries[index].object!, nameIndex: entries[index].nameIndex) }
    
    subscript(next index: Index) -> Index {
        get { entries[index].next }
        set { entries[index].next = newValue }
    }
    
    func find(_ nameIndex: NameTable.Index, _ object: UnsafeObjectPtr) -> Index? {
        find(Key(object: object, nameIndex: nameIndex))
    }
    
    /// Find or create the entry for `nameIndex`
    mutating func entry(for nameIndex: NameTable.Index, _ object: UnsafeObjectPtr) -> (index: Index, isNew: Bool) {
        if let index = find(nameIndex, object) { return (index, false) }
        
        let index: Index
        if let reused = free.popLast() {
            index = reused
            entries[index] = Entry(object: object, nameIndex: nameIndex)
        } else {
            index = Index(rawValue: UInt32(entries.count))
            
            if entries.count == entries.capacity {
                entries.reserveCapacity(NameAndObjectTable.nextCapacity(after: entries.capacity))
            }
            
            entries.append(Entry(object: object, nameIndex: nameIndex))
        }
        
        link(index)
        if nameIndex == .anyNameIndex { nilNameCount += 1 }
        
        return (index, true)
    }
    
    mutating func remove(_ index: Index) {
        if entries[index].nameIndex == .anyNameIndex { nilNameCount -= 1 }
        unlink(index)
        entries[index] = Entry()
        free.append(index)
    }
    
    private static func nextCapacity(after capacity: Int) -> Int {
        Swift.max(16, capacity + capacity / 16) // grow by 1/16th instead of Swift's 2x
    }
    
    struct Index: RawRepresentable, Equatable {
        let rawValue: UInt32
    }
    
    struct Key: Equatable {
        let object: UnsafeObjectPtr
        let nameIndex: NameTable.Index
    }
    
    struct Entry: IntrusiveHashEntry {
        static func hash(_ key: Key) -> UInt64 {
            UInt64(UInt(bitPattern: key.object)) ^ fibonacciHash(UInt64(key.nameIndex.rawValue))
        }
        
        var object: UnsafeObjectPtr? = nil
        var nameIndex: NameTable.Index = .anyNameIndex
        var registrations = SlotMapList<Registration.NameAndObjectLinkage>()
        var next: Index = NameAndObjectTable.end
    }
}

fileprivate extension ContiguousArray<NameAndObjectTable.Entry> {
    subscript(_ index: NameAndObjectTable.Index) -> NameAndObjectTable.Entry {
        get { self[Int(index.rawValue)] }
        _modify { yield &self[Int(index.rawValue)] }
    }
}

// MARK: - RegistrationFilter

// Used by post() to quickly exit when no registrations apply.
internal struct RegistrationFilter : ~Copyable, Sendable {
    private let nameFilter = InlineBloomFilter<64>()
    private let objectFilter = InlineBloomFilter<16>() // objects registered with a nil name
    private let wildcardIsEmpty: Atomic<Bool> = .init(true) // true when there are no registrations with a nil name and a nil object
    
    // No registration matches a post with this name and object
    @inline(__always) func rejects(nameHash: Int, object: PostedObject?) -> Bool {
        guard wildcardIsEmpty.load(ordering: .acquiring),
              !nameFilter.mightContain(hash: nameHash) else { return false }
        guard let object else { return true }
        
        return !objectFilter.mightContain(hash: Self.objectHash(object.pointer))
    }
    
    func insertName(hash: Int) {
        nameFilter.insert(hash: hash)
    }
    
    func insertNilNameObject(_ object: UnsafeObjectPtr) {
        objectFilter.insert(hash: Self.objectHash(object))
    }
    
    func setWildcardIsEmpty(_ isEmpty: Bool) {
        wildcardIsEmpty.store(isEmpty, ordering: .releasing)
    }
    
    func namesAreStale(liveCount: Int) -> Bool {
        nameFilter.insertCount.load(ordering: .relaxed) > 2 * liveCount
    }
    
    func nilNameObjectsAreStale(liveCount: Int) -> Bool {
        objectFilter.insertCount.load(ordering: .relaxed) > 2 * liveCount
    }
    
    @inline(never) func rebuildNames(_ hashes: some Sequence<Int>) {
        nameFilter.rebuild(fromHashes: hashes)
    }
    
    @inline(never) func rebuildNilNameObjects(_ objects: some Sequence<UnsafeObjectPtr>) {
        objectFilter.rebuild(fromHashes: objects.lazy.map(Self.objectHash))
    }
    
    @inline(__always) private static func objectHash(_ object: UnsafeObjectPtr) -> Int {
        Int(truncatingIfNeeded: fibonacciHash(UInt64(UInt(bitPattern: object))))
    }
}

// MARK: - DeliveryCollector

// Collects a post's matched observers to be called outside the lock. Uses a stack-local sort network before trying heap as most posts fall within four observers or less.
fileprivate struct DeliveryCollector: ~Copyable {
    private var s0: Delivery?, s1: Delivery?, s2: Delivery?, s3: Delivery?
    private var t0: UInt64 = 0, t1: UInt64 = 0, t2: UInt64 = 0, t3: UInt64 = 0
    private var overflow: UnsafeMutableBufferPointer<Delivery>
    private var overflowIsHeap = false
    private var overflowCount = 0
    private(set) var count: Int = 0
    
    init(stack: UnsafeMutableBufferPointer<Delivery>) {
        overflow = stack
    }
    
    private mutating func appendToOverflow(_ resolved: consuming Delivery) {
        if overflowCount == overflow.count {
            let grown = UnsafeMutableBufferPointer<Delivery>.allocate(capacity: overflow.count * 2)
            
            grown.baseAddress!.moveInitialize(from: overflow.baseAddress!, count: overflowCount)
            
            if overflowIsHeap { overflow.deallocate() }
            
            overflow = grown
            overflowIsHeap = true
        }
        
        (overflow.baseAddress! + overflowCount).initialize(to: resolved)
        overflowCount += 1
    }
    
    mutating func append(_ resolved: consuming Delivery) {
        let token = resolved.token.rawValue
        
        switch count {
        case 0: t0 = token; s0 = consume resolved
        case 1: t1 = token; s1 = consume resolved
        case 2: t2 = token; s2 = consume resolved
        case 3: t3 = token; s3 = consume resolved
        default: appendToOverflow(resolved)
        }
        
        count += 1
    }
    
    mutating func sortedForEach(_ body: (borrowing Delivery) -> Void) {
        guard count > 0 else { return }
        
        if count <= 4 {
            // Sort network-based forEach
            
            switch count {
            case 1: break
            case 2:
                if t0 > t1 { swap(&s0, &s1); swap(&t0, &t1) }
            case 3:
                if t0 > t1 { swap(&s0, &s1); swap(&t0, &t1) }
                if t1 > t2 { swap(&s1, &s2); swap(&t1, &t2) }
                if t0 > t1 { swap(&s0, &s1); swap(&t0, &t1) }
            default: // 4
                if t0 > t1 { swap(&s0, &s1); swap(&t0, &t1) }
                if t2 > t3 { swap(&s2, &s3); swap(&t2, &t3) }
                if t0 > t2 { swap(&s0, &s2); swap(&t0, &t2) }
                if t1 > t3 { swap(&s1, &s3); swap(&t1, &t3) }
                if t1 > t2 { swap(&s1, &s2); swap(&t1, &t2) }
            }
            
            switch s0 { case let observer?: body(observer); case nil: break }
            guard count > 1 else { return }
            switch s1 { case let observer?: body(observer); case nil: break }
            guard count > 2 else { return }
            switch s2 { case let observer?: body(observer); case nil: break }
            guard count > 3 else { return }
            switch s3 { case let observer?: body(observer); case nil: break }
        } else {
            appendToOverflow(s0.take()!)
            appendToOverflow(s1.take()!)
            appendToOverflow(s2.take()!)
            appendToOverflow(s3.take()!)
            
            // Sort (token, position) pairs and dispatch each observer in place
            withUnsafeTemporaryAllocation(of: (token: UInt64, position: Int).self, capacity: overflowCount) { order in
                var order = order
                
                for i in 0..<overflowCount {
                    order.initializeElement(at: i, to: (overflow[i].token.rawValue, i))
                }
                
                order.sort { $0.token < $1.token }
                
                for entry in order {
                    body(overflow[entry.position])
                }
            }
        }
    }
    
    deinit {
        overflow.baseAddress!.deinitialize(count: overflowCount)
        
        if overflowIsHeap {
            overflow.deallocate()
        }
    }
    
    /// `Delivery` instances are created during post() under the lock and store everything needed to call the appropriate registrations.
    /// NotificationCenter supports re-entrancy so `Delivery` persists information that may be destroyed by the callbacks themselves.
    struct Delivery: ~Copyable {
        let token: Token
        let handler: Handler
    
    #if FOUNDATION_FRAMEWORK
        var queue: ObserverQueue? {
            if case .closure(_, let queue) = handler { return queue }
            return nil
        }
    #endif
    
        init?(_ handler: Registration.Handler, _ token: Token, cfCenter: UnsafeRawPointer?) {
            switch handler {
            case .closure(let block, let queue):
                self.handler = .closure(block, queue)
#if FOUNDATION_FRAMEWORK
            case .selector(let selector, let reference):
                guard let observer = Delivery.Handler.Observer(reference) else { return nil }
                self.handler = .selector(observer, selector)
            case .function(let callback, let reference):
                guard let observer = Delivery.Handler.Observer(reference) else { return nil }
                self.handler = .function(callback, center: cfCenter, observer: observer)
#endif
            }
        
            self.token = token
        }

        // A handler resolved under the lock, with weak observers loaded as strong references
        fileprivate enum Handler {
            // CF callbacks only need a notification's fields, so avoid building the notification if possible
            var needsNotificationBuilt: Bool {
            #if FOUNDATION_FRAMEWORK
                if case .function = self { return false }
            #endif
                return true
            }

            case closure(ObserverBlock, ObserverQueue?)
            #if FOUNDATION_FRAMEWORK
            typealias SelectorIMP = @convention(c) (AnyObject, Selector, NSNotification?) -> Void
            case selector(Handler.Observer, Selector)
            case function(RawCFNotificationCallback, center: UnsafeRawPointer?, observer: Handler.Observer)
            #endif
            
            func dispatch(name: RegistrarStringType, object: UnsafeObjectPtr?, userInfo: AnyObject?, notification: NotificationType?) {
                switch self {
                case .closure(let block, _):
                    block(notification!)
            #if FOUNDATION_FRAMEWORK
                case .selector(.strong(let observer), let selector):
                    guard let cls = object_getClass(observer) else { break }
                    let fn = unsafeBitCast(class_getMethodImplementation(cls, selector), to: SelectorIMP.self)
                    fn(observer, selector, notification!)
                case .selector(.raw(let pointer), let selector):
                    Unmanaged<AnyObject>.fromOpaque(pointer!)._withUnsafeGuaranteedRef { observer in
                        guard let cls = object_getClass(observer) else { return }
                        let fn = unsafeBitCast(class_getMethodImplementation(cls, selector), to: SelectorIMP.self)
                        fn(observer, selector, notification!)
                    }
                case .function(let callback, let center, .strong(let observer)):
                    callback(center, UnsafeRawPointer(observer), UnsafeRawPointer(name), object, UnsafeRawPointer(userInfo))
                case .function(let callback, let center, .raw(let observer)):
                    callback(center, observer, UnsafeRawPointer(name), object, UnsafeRawPointer(userInfo))
            #endif
                }
            }
            
            #if FOUNDATION_FRAMEWORK
            // Registration.Handler.Observer with a weak observer loaded as a strong reference for the delivery
            fileprivate enum Observer {
                case strong(AnyObject)
                case raw(UnsafeRawPointer?)
            
                init?(_ reference: Registration.Handler.Observer) {
                    switch reference {
                    case .weak(let entry):
                        guard let object = entry.pointee.weakObserver else { return nil }
                        self = .strong(object)
                    case .raw(let pointer):
                        self = .raw(pointer)
                    }
                }
            }
            #endif
        }
    }
}

// Call-stack canary. Do not optimize - the value is in seeing the silgen name in the callstack during debugging.
@_silgen_name("__NOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__") @inline(never) @_optimize(none)
fileprivate func callOutToObserver(_ handler: borrowing DeliveryCollector.Delivery.Handler, name: RegistrarStringType, object: UnsafeObjectPtr?, userInfo: AnyObject?, notification: borrowing NotificationType?) {
    handler.dispatch(name: name, object: object, userInfo: userInfo, notification: notification)
}

// A few areas of NotificationRegistrar and its supporting types use Fibonacci hashing which is faster than Hasher if you don't need the seed

// Fibonacci hashing. Magic number is (2^64 / φ), used for fast, multiplicative hashing
@inline(__always) internal func fibonacciHash(_ key: UInt64) -> UInt64 { key &* 0x9E37_79B9_7F4A_7C15 }

// Maps a key to a slot using the hash's top bits. Count must be a power of two.
@inline(__always) internal func fibonacciIndex(_ key: UInt64, count: Int) -> Int {
    Int(truncatingIfNeeded: fibonacciHash(key) >> UInt64(64 - count.trailingZeroBitCount))
}

#endif
