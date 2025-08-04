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

internal import Synchronization

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    
    /// Returns a summary for specified property in subtree.
    /// - Parameter metatype: Type of property.
    /// - Returns: Summary of property as specified.
    
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Int, P.Summary == Int {
        return getUpdatedIntSummary(property: MetatypeWrapper(property))
    }
    
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Double, P.Summary == Double {
        return getUpdatedDoubleSummary(property: MetatypeWrapper(property))
    }
    
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == String, P.Summary == String {
        return getUpdatedStringSummary(property: MetatypeWrapper(property))
    }
    
    public func summary(of property: ProgressManager.Properties.TotalFileCount.Type) -> Int {
        return getUpdatedFileCount(type: .total)
    }
    
    public func summary(of property: ProgressManager.Properties.CompletedFileCount.Type) -> Int {
        return getUpdatedFileCount(type: .completed)
    }
    
    public func summary(of property: ProgressManager.Properties.TotalByteCount.Type) -> Int64 {
        return getUpdatedByteCount(type: .total)
    }
    
    public func summary(of property: ProgressManager.Properties.CompletedByteCount.Type) -> Int64 {
        return getUpdatedByteCount(type: .completed)
    }
    
    public func summary(of property: ProgressManager.Properties.Throughput.Type) -> Int64 {
        let throughput = getUpdatedThroughput()
        return throughput.values / Int64(throughput.count)
    }
    
    public func summary(of property: ProgressManager.Properties.EstimatedTimeRemaining.Type) -> Duration {
        return getUpdatedEstimatedTimeRemaining()
    }
    
    public func summary(of property: ProgressManager.Properties.FileURL.Type) -> [URL] {
        return getUpdatedFileURL()
    }
    
    // MARK: Additional Properties Methods
    internal func getProperties<T, E: Error>(
        _ closure: (sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        try state.withLock { state throws(E) -> T in
            let values = Values(state: state)
            let result = try closure(values)
            return result
        }
    }
    
    /// Mutates any settable properties that convey information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (inout sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        return try state.withLock { (state) throws(E) -> T in
            var values = Values(state: state)
            // This is done to avoid copy on write later
            state = State(
                selfFraction: ProgressFraction(),
                children: [],
                parents: [],
                totalFileCount: ProgressManager.Properties.TotalFileCount.defaultValue,
                completedFileCount: ProgressManager.Properties.CompletedFileCount.defaultValue,
                totalByteCount: ProgressManager.Properties.TotalByteCount.defaultValue,
                completedByteCount: ProgressManager.Properties.CompletedByteCount.defaultValue,
                throughput: ProgressManager.Properties.Throughput.defaultValue,
                estimatedTimeRemaining: ProgressManager.Properties.EstimatedTimeRemaining.defaultValue,
                propertiesInt: [:],
                propertiesDouble: [:],
                propertiesString: [:],
                interopObservation: InteropObservation(subprogressBridge: nil),
                observers: []
            )
            let result = try closure(&values)
            if values.fractionalCountDirty {
                markSelfDirty(parents: values.state.parents)
            }
            
            if values.totalFileCountDirty {
                markSelfDirty(property: Properties.TotalFileCount.self, parents: values.state.parents)
            }
            
            if values.completedFileCountDirty {
                markSelfDirty(property: Properties.CompletedFileCount.self, parents: values.state.parents)
            }
            
            if values.totalByteCountDirty {
                markSelfDirty(property: Properties.TotalByteCount.self, parents: values.state.parents)
            }
            
            if values.completedByteCountDirty {
                markSelfDirty(property: Properties.CompletedByteCount.self, parents: values.state.parents)
            }
            
            if values.throughputDirty {
                markSelfDirty(property: Properties.Throughput.self, parents: values.state.parents)
            }
            
            if values.estimatedTimeRemainingDirty {
                markSelfDirty(property: Properties.EstimatedTimeRemaining.self, parents: values.state.parents)
            }
            
            if values.fileURLDirty {
                markSelfDirty(property: Properties.FileURL.self, parents: values.state.parents)
            }
            
            if values.dirtyPropertiesInt.count > 0 {
                for property in values.dirtyPropertiesInt {
                    markSelfDirty(property: property, parents: values.state.parents)
                }
            }
            
            if values.dirtyPropertiesDouble.count > 0 {
                for property in values.dirtyPropertiesDouble {
                    markSelfDirty(property: property, parents: values.state.parents)
                }
            }
            
            if values.dirtyPropertiesString.count > 0 {
                for property in values.dirtyPropertiesString {
                    markSelfDirty(property: property, parents: values.state.parents)
                }
            }
            
            if let observerState = values.observerState {
                if let _ = state.interopObservation.reporterBridge {
                    notifyObservers(with: observerState)
                }
            }
            state = values.state
            return result
        }
    }
    
    /// A container that holds values for properties that specify information on progress.
    @dynamicMemberLookup
    public struct Values : Sendable {
        //TODO: rdar://149225947 Non-escapable conformance
        internal var state: State
        
        internal var fractionalCountDirty = false
        internal var totalFileCountDirty = false
        internal var completedFileCountDirty = false
        internal var totalByteCountDirty = false
        internal var completedByteCountDirty = false
        internal var throughputDirty = false
        internal var estimatedTimeRemainingDirty = false
        internal var fileURLDirty = false
        internal var dirtyPropertiesInt: [MetatypeWrapper<Int>] = []
        internal var dirtyPropertiesDouble: [MetatypeWrapper<Double>] = []
        internal var dirtyPropertiesString: [MetatypeWrapper<String>] = []
        internal var observerState: ObserverState?
                
        /// The total units of work.
        public var totalCount: Int? {
            get {
                state.getTotalCount()
            }
            
            set {
                guard newValue != state.selfFraction.total else {
                    return
                }
                
                state.selfFraction.total = newValue
                
                interopNotifications()
                
                fractionalCountDirty = true
            }
        }
        
        /// The completed units of work.
        public var completedCount: Int {
            mutating get {
                state.getCompletedCount()
            }
            
            set {
                guard newValue != state.selfFraction.completed else {
                    return
                }
                
                state.selfFraction.completed = newValue
                
                interopNotifications()

                fractionalCountDirty = true
            }
        }
        
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.TotalFileCount.Type>) -> Int {
            get {
                return state.totalFileCount
            }
            
            set {
                
                guard newValue != state.totalFileCount else {
                    return
                }
                
                state.totalFileCount = newValue
                
                totalFileCountDirty = true
            }
        }
        
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.CompletedFileCount.Type>) -> Int {
            get {
                return state.completedFileCount
            }
            
            set {
                
                guard newValue != state.completedFileCount else {
                    return
                }
                
                state.completedFileCount = newValue
                
                completedFileCountDirty = true
            }
        }
        
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.TotalByteCount.Type>) -> Int64 {
            get {
                return state.totalByteCount
            }
            
            set {
                guard newValue != state.totalByteCount else {
                    return
                }
                
                state.totalByteCount = newValue

                totalByteCountDirty = true
            }
        }
        
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.CompletedByteCount.Type>) -> Int64 {
            get {
                return state.completedByteCount
            }
            
            set {
                guard newValue != state.completedByteCount else {
                    return
                }
                
                state.completedByteCount = newValue

                completedByteCountDirty = true
            }
        }
        
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.Throughput.Type>) -> Int64 {
            get {
                return state.throughput
            }
            
            set {
                guard newValue != state.throughput else {
                    return
                }
                
                state.throughput = newValue

                throughputDirty = true
            }
        }
        
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.EstimatedTimeRemaining.Type>) -> Duration {
            get {
                return state.estimatedTimeRemaining
            }
            
            set {
                guard newValue != state.estimatedTimeRemaining else {
                    return
                }
                
                state.estimatedTimeRemaining = newValue

                estimatedTimeRemainingDirty = true
            }
        }
        
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.FileURL.Type>) -> URL? {
            get {
                return state.fileURL
            }
            
            set {
                guard newValue != state.fileURL else {
                    return
                }
                
                state.fileURL = newValue
                
                fileURLDirty = true
            }
        }
        
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P.Value == Int, P.Summary == Int {
            get {
                return state.propertiesInt[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
            
            set {
                guard newValue != state.propertiesInt[MetatypeWrapper(P.self)] else {
                    return
                }
                   
                state.propertiesInt[MetatypeWrapper(P.self)] = newValue

                dirtyPropertiesInt.append(MetatypeWrapper(P.self))
            }
        }
        
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value where P.Value == Double, P.Summary == Double {
            get {
                return state.propertiesDouble[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
            
            set {
                guard newValue != state.propertiesDouble[MetatypeWrapper(P.self)] else {
                    return
                }
                
                state.propertiesDouble[MetatypeWrapper(P.self)] = newValue
                
                dirtyPropertiesDouble.append(MetatypeWrapper(P.self))
            }
        }
        
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> String where P.Value == String, P.Summary == String {
            get {
                return state.propertiesString[MetatypeWrapper(P.self)] ?? P.self.defaultValue
            }

            set {
                guard newValue != state.propertiesString[MetatypeWrapper(P.self)] else {
                    return
                }

                state.propertiesString[MetatypeWrapper(P.self)] = newValue

                dirtyPropertiesString.append(MetatypeWrapper(P.self))
            }
        }
        
        private mutating func interopNotifications() {
            state.interopObservation.subprogressBridge?.manager.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed))
            
            self.observerState = .fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed)
        }
    }
}
