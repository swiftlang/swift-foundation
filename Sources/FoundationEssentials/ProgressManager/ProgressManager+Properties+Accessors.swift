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
    
    /// Returns a summary for the specified integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom integer property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the integer property to summarize. Must be a property
    ///   where both the value and summary types are `Int`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Int, P.Summary == Int {
        return getUpdatedIntSummary(property: MetatypeWrapper(property))
    }
    
    /// Returns a summary for the specified double property across the progress subtree.
    ///
    /// This method aggregates the values of a custom double property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the double property to summarize. Must be a property
    ///   where both the value and summary types are `Double`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Double, P.Summary == Double {
        return getUpdatedDoubleSummary(property: MetatypeWrapper(property))
    }
    
    /// Returns a summary for the specified string property across the progress subtree.
    ///
    /// This method aggregates the values of a custom string property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the string property to summarize. Must be a property
    ///   where both the value and summary types are `String`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == String, P.Summary == String {
        return getUpdatedStringSummary(property: MetatypeWrapper(property))
    }
    
    /// Returns the total file count across the progress subtree.
    ///
    /// - Parameter property: The `TotalFileCount` property type.
    /// - Returns: The sum of all total file counts across the entire progress subtree.
    public func summary(of property: ProgressManager.Properties.TotalFileCount.Type) -> Int {
        return getUpdatedFileCount(type: .total)
    }
    
    /// Returns the completed file count across the progress subtree.
    ///
    /// - Parameter property: The `CompletedFileCount` property type.
    /// - Returns: The sum of all completed file counts across the entire progress subtree.
    public func summary(of property: ProgressManager.Properties.CompletedFileCount.Type) -> Int {
        return getUpdatedFileCount(type: .completed)
    }
    
    /// Returns the total byte count across the progress subtree.
    ///
    /// - Parameter property: The `TotalByteCount` property type.
    /// - Returns: The sum of all total byte counts across the entire progress subtree, in bytes.
    public func summary(of property: ProgressManager.Properties.TotalByteCount.Type) -> UInt64 {
        return getUpdatedByteCount(type: .total)
    }
    
    /// Returns the completed byte count across the progress subtree.
    ///
    /// - Parameter property: The `CompletedByteCount` property type.
    /// - Returns: The sum of all completed byte counts across the entire progress subtree, in bytes.
    public func summary(of property: ProgressManager.Properties.CompletedByteCount.Type) -> UInt64 {
        return getUpdatedByteCount(type: .completed)
    }
    
    /// Returns the average throughput across the progress subtree.
    ///
    /// - Parameter property: The `Throughput` property type.
    /// - Returns: The average throughput across the entire progress subtree, in bytes per second.
    ///
    /// - Note: The throughput is calculated as the sum of all throughput values divided by the count
    ///   of progress managers that have throughput data.
    public func summary(of property: ProgressManager.Properties.Throughput.Type) -> UInt64 {
        let throughput = getUpdatedThroughput()
        return throughput.values / UInt64(throughput.count)
    }
    
    /// Returns the maximum estimated time remaining for completion across the progress subtree.
    ///
    /// - Parameter property: The `EstimatedTimeRemaining` property type.
    /// - Returns: The estimated duration until completion for the entire progress subtree.
    ///
    /// - Note: The estimation is based on current throughput and remaining work. The accuracy
    ///   depends on the consistency of the processing rate.
    public func summary(of property: ProgressManager.Properties.EstimatedTimeRemaining.Type) -> Duration {
        return getUpdatedEstimatedTimeRemaining()
    }
    
    /// Returns all file URLs being processed across the progress subtree.
    ///
    /// - Parameter property: The `FileURL` property type.
    /// - Returns: An array containing all file URLs across the entire progress subtree.
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
#if FOUNDATION_FRAMEWORK
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
#else
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
                propertiesString: [:]
            )
#endif
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
#if FOUNDATION_FRAMEWORK
            if let observerState = values.observerState {
                if let _ = state.interopObservation.reporterBridge {
                    notifyObservers(with: observerState)
                }
            }
#endif
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
#if FOUNDATION_FRAMEWORK
        internal var observerState: ObserverState?
#endif
                
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
                
#if FOUNDATION_FRAMEWORK
                interopNotifications()
#endif
                
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
                
#if FOUNDATION_FRAMEWORK
                interopNotifications()
#endif
                fractionalCountDirty = true
            }
        }
        
        /// Gets or sets the total file count property.
        /// - Parameter key: A key path to the `TotalFileCount` property type.
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
        
        /// Gets or sets the completed file count property.
        /// - Parameter key: A key path to the `CompletedFileCount` property type.
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
        
        /// Gets or sets the total byte count property.
        /// - Parameter key: A key path to the `TotalByteCount` property type.
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.TotalByteCount.Type>) -> UInt64 {
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
        
        /// Gets or sets the completed byte count property.
        /// - Parameter key: A key path to the `CompletedByteCount` property type.
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.CompletedByteCount.Type>) -> UInt64 {
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
        
        /// Gets or sets the throughput property.
        /// - Parameter key: A key path to the `Throughput` property type.
        public subscript(dynamicMember key: KeyPath<ProgressManager.Properties, ProgressManager.Properties.Throughput.Type>) -> UInt64 {
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
        
        /// Gets or sets the estimated time remaining property.
        /// - Parameter key: A key path to the `EstimatedTimeRemaining` property type.
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
        
        /// Gets or sets the file URL property.
        /// - Parameter key: A key path to the `FileURL` property type.
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
        
        /// Gets or sets custom integer properties.
        ///
        /// This subscript provides read-write access to custom progress properties where both the value
        /// and summary types are `Int`. If the property has not been set, the getter returns the
        /// property's default value.
        ///
        /// - Parameter key: A key path to the custom integer property type.
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
        
        /// Gets or sets custom double properties.
        ///
        /// This subscript provides read-write access to custom progress properties where both the value
        /// and summary types are `Double`. If the property has not been set, the getter returns the
        /// property's default value.
        ///
        /// - Parameter key: A key path to the custom double property type.
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
        
        /// Gets or sets custom string properties.
        ///
        /// This subscript provides read-write access to custom progress properties where both the value
        /// and summary types are `String`. If the property has not een set, the getter returns the
        /// property's default value.
        ///
        /// - Parameter key: A key path to the custom string property type.
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
#if FOUNDATION_FRAMEWORK
        private mutating func interopNotifications() {
            state.interopObservation.subprogressBridge?.manager.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed))
            
            self.observerState = .fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed)
        }
#endif
    }
}
