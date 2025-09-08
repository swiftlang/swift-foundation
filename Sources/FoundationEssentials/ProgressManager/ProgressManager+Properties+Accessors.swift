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

@available(FoundationPreview 6.3, *)
extension ProgressManager {
    
    // MARK: Methods to Read & Write Additional Properties of single ProgressManager node
    
    /// Internal struct to collect dirty tracking information from within the lock
    private struct DirtyTrackingInfo {
        let parents: [ParentState]
        let fractionalCountDirty: Bool
        let totalFileCountDirty: Bool
        let completedFileCountDirty: Bool
        let totalByteCountDirty: Bool
        let completedByteCountDirty: Bool
        let throughputDirty: Bool
        let estimatedTimeRemainingDirty: Bool
        let dirtyPropertiesInt: [MetatypeWrapper<Int, Int>]
        let dirtyPropertiesUInt64: [MetatypeWrapper<UInt64, UInt64>]
        let dirtyPropertiesDouble: [MetatypeWrapper<Double, Double>]
        let dirtyPropertiesString: [MetatypeWrapper<String?, [String?]>]
        let dirtyPropertiesURL: [MetatypeWrapper<URL?, [URL?]>]
        let dirtyPropertiesUInt64Array: [MetatypeWrapper<UInt64, [UInt64]>]
        let dirtyPropertiesDuration: [MetatypeWrapper<Duration, Duration>]
#if FOUNDATION_FRAMEWORK
        let observerState: ObserverState?
        let interopType: InteropType?
#endif
    }
    
    /// Mutates any settable properties that convey information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (inout sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        // Collect dirty flags and parent information within the lock
        accessObservation(keyPath: \.totalCount)
        accessObservation(keyPath: \.completedCount)
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        let (result, dirtyInfo) = try state.withLock { (state) throws(E) -> (T, DirtyTrackingInfo) in
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
                propertiesUInt64: [:],
                propertiesDouble: [:],
                propertiesString: [:],
                propertiesURL: [:],
                propertiesUInt64Array: [:],
                propertiesDuration: [:],
                observers: [],
                interopType: nil,
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
                propertiesUInt64: [:],
                propertiesDouble: [:],
                propertiesString: [:],
                propertiesURL: [:],
                propertiesUInt64Array: [:],
                propertiesDuration: [:]
            )
#endif
            let result = try closure(&values)
            
#if FOUNDATION_FRAMEWORK
            // Collect all dirty information
            let dirtyInfo = DirtyTrackingInfo(
                parents: values.state.parents,
                fractionalCountDirty: values.fractionalCountDirty,
                totalFileCountDirty: values.totalFileCountDirty,
                completedFileCountDirty: values.completedFileCountDirty,
                totalByteCountDirty: values.totalByteCountDirty,
                completedByteCountDirty: values.completedByteCountDirty,
                throughputDirty: values.throughputDirty,
                estimatedTimeRemainingDirty: values.estimatedTimeRemainingDirty,
                dirtyPropertiesInt: values.dirtyPropertiesInt,
                dirtyPropertiesUInt64: values.dirtyPropertiesUInt64,
                dirtyPropertiesDouble: values.dirtyPropertiesDouble,
                dirtyPropertiesString: values.dirtyPropertiesString,
                dirtyPropertiesURL: values.dirtyPropertiesURL,
                dirtyPropertiesUInt64Array: values.dirtyPropertiesUInt64Array,
                dirtyPropertiesDuration: values.dirtyPropertiesDuration,
                observerState: values.observerState,
                interopType: state.interopType
            )
#else
            let dirtyInfo = DirtyTrackingInfo(
                parents: values.state.parents,
                fractionalCountDirty: values.fractionalCountDirty,
                totalFileCountDirty: values.totalFileCountDirty,
                completedFileCountDirty: values.completedFileCountDirty,
                totalByteCountDirty: values.totalByteCountDirty,
                completedByteCountDirty: values.completedByteCountDirty,
                throughputDirty: values.throughputDirty,
                estimatedTimeRemainingDirty: values.estimatedTimeRemainingDirty,
                dirtyPropertiesInt: values.dirtyPropertiesInt,
                dirtyPropertiesUInt64: values.dirtyPropertiesUInt64,
                dirtyPropertiesDouble: values.dirtyPropertiesDouble,
                dirtyPropertiesString: values.dirtyPropertiesString,
                dirtyPropertiesURL: values.dirtyPropertiesURL,
                dirtyPropertiesUInt64Array: values.dirtyPropertiesUInt64Array,
                dirtyPropertiesDuration: values.dirtyPropertiesDuration
            )
#endif

            
#if FOUNDATION_FRAMEWORK
            if let observerState = values.observerState {
                switch state.interopType {
                case .interopObservation(let observation):
                    if let _ = observation.reporterBridge {
                        notifyObservers(with: observerState)
                    }
                case .interopMirror:
                    break
                default:
                    break
                }
            }
#endif
            state = values.state
            return (result, dirtyInfo)
        }
        
        // Now handle all the dirty marking outside the lock
        // Mark all dirty properties outside the lock
        if dirtyInfo.fractionalCountDirty {
            markSelfDirty(parents: dirtyInfo.parents)
        }
        
        if dirtyInfo.totalFileCountDirty {
            markSelfDirty(property: Properties.TotalFileCount.self, parents: dirtyInfo.parents)
        }
        
        if dirtyInfo.completedFileCountDirty {
            markSelfDirty(property: Properties.CompletedFileCount.self, parents: dirtyInfo.parents)
        }
        
        if dirtyInfo.totalByteCountDirty {
            markSelfDirty(property: Properties.TotalByteCount.self, parents: dirtyInfo.parents)
        }
        
        if dirtyInfo.completedByteCountDirty {
            markSelfDirty(property: Properties.CompletedByteCount.self, parents: dirtyInfo.parents)
        }
        
        if dirtyInfo.throughputDirty {
            markSelfDirty(property: Properties.Throughput.self, parents: dirtyInfo.parents)
        }
        
        if dirtyInfo.estimatedTimeRemainingDirty {
            markSelfDirty(property: Properties.EstimatedTimeRemaining.self, parents: dirtyInfo.parents)
        }
        
        if dirtyInfo.dirtyPropertiesInt.count > 0 {
            for property in dirtyInfo.dirtyPropertiesInt {
                markSelfDirty(property: property, parents: dirtyInfo.parents)
            }
        }
        
        if dirtyInfo.dirtyPropertiesUInt64.count > 0 {
            for property in dirtyInfo.dirtyPropertiesInt {
                markSelfDirty(property: property, parents: dirtyInfo.parents)
            }
        }
        
        if dirtyInfo.dirtyPropertiesDouble.count > 0 {
            for property in dirtyInfo.dirtyPropertiesDouble {
                markSelfDirty(property: property, parents: dirtyInfo.parents)
            }
        }
        
        if dirtyInfo.dirtyPropertiesString.count > 0 {
            for property in dirtyInfo.dirtyPropertiesString {
                markSelfDirty(property: property, parents: dirtyInfo.parents)
            }
        }
        
        if dirtyInfo.dirtyPropertiesURL.count > 0 {
            for property in dirtyInfo.dirtyPropertiesURL {
                markSelfDirty(property: property, parents: dirtyInfo.parents)
            }
        }
            
        if dirtyInfo.dirtyPropertiesUInt64Array.count > 0 {
            for property in dirtyInfo.dirtyPropertiesUInt64Array {
                markSelfDirty(property: property, parents: dirtyInfo.parents)
            }
        }
        
        if dirtyInfo.dirtyPropertiesDuration.count > 0 {
            for property in dirtyInfo.dirtyPropertiesDuration {
                markSelfDirty(property: property, parents: dirtyInfo.parents)
            }
        }
        
        return result
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
        internal var dirtyPropertiesInt: [MetatypeWrapper<Int, Int>] = []
        internal var dirtyPropertiesUInt64: [MetatypeWrapper<UInt64, UInt64>] = []
        internal var dirtyPropertiesDouble: [MetatypeWrapper<Double, Double>] = []
        internal var dirtyPropertiesString: [MetatypeWrapper<String?, [String?]>] = []
        internal var dirtyPropertiesURL: [MetatypeWrapper<URL?, [URL?]>] = []
        internal var dirtyPropertiesUInt64Array: [MetatypeWrapper<UInt64, [UInt64]>] = []
        internal var dirtyPropertiesDuration: [MetatypeWrapper<Duration, Duration>] = []
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
        
        /// Gets or sets custom integer properties.
        ///
        /// This subscript provides read-write access to custom progress properties where both the value
        /// and summary types are `Int`. If the property has not been set, the getter returns the
        /// property's default value.
        ///
        /// - Parameter key: A key path to the custom integer property type.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P.Value == Int, P.Summary == Int {
            get {
                if P.self == ProgressManager.Properties.TotalFileCount.self {
                    return state.totalFileCount
                } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
                    return state.completedFileCount
                } else {
                    return state.propertiesInt[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
            
            set {
                if P.self == ProgressManager.Properties.TotalFileCount.self {
                    guard newValue != state.totalFileCount else {
                        return
                    }
                    
                    state.totalFileCount = newValue
                    
                    totalFileCountDirty = true
                } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
                    guard newValue != state.completedFileCount else {
                        return
                    }
                    
                    state.completedFileCount = newValue
                    
                    completedFileCountDirty = true
                } else {
                    guard newValue != state.propertiesInt[MetatypeWrapper(P.self)] else {
                        return
                    }
                       
                    state.propertiesInt[MetatypeWrapper(P.self)] = newValue

                    dirtyPropertiesInt.append(MetatypeWrapper(P.self))
                }
                
            }
        }
        
        /// Gets or sets custom integer properties.
        ///
        /// This subscript provides read-write access to custom progress properties where both the value
        /// and summary types are `UInt64`. If the property has not been set, the getter returns the
        /// property's default value.
        ///
        /// - Parameter key: A key path to the custom integer property type.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == UInt64 {
            get {
                if P.self == ProgressManager.Properties.TotalByteCount.self {
                    return state.totalByteCount
                } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
                    return state.completedByteCount
                } else {
                    return state.propertiesUInt64[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
            
            set {
                if P.self == ProgressManager.Properties.TotalByteCount.self {
                    guard newValue != state.totalByteCount else {
                        return
                    }
                    
                    state.totalByteCount = newValue

                    totalByteCountDirty = true
                } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
                    guard newValue != state.completedByteCount else {
                        return
                    }
                    
                    state.completedByteCount = newValue

                    completedByteCountDirty = true
                } else {
                    guard newValue != state.propertiesUInt64[MetatypeWrapper(P.self)] else {
                        return
                    }
                       
                    state.propertiesUInt64[MetatypeWrapper(P.self)] = newValue

                    dirtyPropertiesUInt64.append(MetatypeWrapper(P.self))

                }
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
        /// This subscript provides read-write access to custom progress properties where the value
        /// type is `String?` and the summary type is `[String?]`. If the property has not been set,
        /// the getter returns the property's default value.
        ///
        /// - Parameter key: A key path to the custom string property type.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> String? where P.Value == String?, P.Summary == [String?] {
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
        
        /// Gets or sets custom URL properties.
        ///
        /// This subscript provides read-write access to custom progress properties where the value
        /// type is `URL?` and the summary type is `[URL?]`. If the property has not been set,
        /// the getter returns the property's default value.
        ///
        /// - Parameter key: A key path to the custom URL property type.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> URL? where P.Value == URL?, P.Summary == [URL?] {
            get {
                return state.propertiesURL[MetatypeWrapper(P.self)] ?? P.self.defaultValue
            }

            set {
                guard newValue != state.propertiesURL[MetatypeWrapper(P.self)] else {
                    return
                }

                state.propertiesURL[MetatypeWrapper(P.self)] = newValue

                dirtyPropertiesURL.append(MetatypeWrapper(P.self))
            }
        }
        
        /// Gets or sets custom UInt64 properties.
        ///
        /// This subscript provides read-write access to custom progress properties where the value
        /// type is `UInt64` and the summary type is `[UInt64]`. If the property has not been set,
        /// the getter returns the property's default value.
        ///
        /// - Parameter key: A key path to the custom UInt64 property type.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == [UInt64] {
            get {
                if P.self == ProgressManager.Properties.Throughput.self {
                    return state.throughput
                } else {
                    return state.propertiesUInt64Array[MetatypeWrapper(P.self)] ?? P.self.defaultValue
                }
            }

            set {
                if P.self == ProgressManager.Properties.Throughput.self {
                    guard newValue != state.throughput else {
                        return
                    }
                    
                    state.throughput = newValue

                    throughputDirty = true
                } else {
                    guard newValue != state.propertiesUInt64Array[MetatypeWrapper(P.self)] else {
                        return
                    }

                    state.propertiesUInt64Array[MetatypeWrapper(P.self)] = newValue

                    dirtyPropertiesUInt64Array.append(MetatypeWrapper(P.self))
                }
            }
        }
        
        /// Gets or sets custom Duration properties.
        ///
        /// This subscript provides read-write access to custom progress properties where the value
        /// type is `Duration` and the summary type is `Duration`. If the property has not been set,
        /// the getter returns the property's default value.
        ///
        /// - Parameter key: A key path to the custom Duration property type.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Duration where P.Value == Duration, P.Summary == Duration {
            get {
                if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
                    return state.estimatedTimeRemaining
                } else {
                    return state.propertiesDuration[MetatypeWrapper(P.self)] ?? P.self.defaultValue
                }
            }

            set {
                if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
                    guard newValue != state.estimatedTimeRemaining else {
                        return
                    }
                    
                    state.estimatedTimeRemaining = newValue

                    estimatedTimeRemainingDirty = true
                } else {
                    guard newValue != state.propertiesDuration[MetatypeWrapper(P.self)] else {
                        return
                    }

                    state.propertiesDuration[MetatypeWrapper(P.self)] = newValue

                    dirtyPropertiesDuration.append(MetatypeWrapper(P.self))
                }
            }
        }
        
#if FOUNDATION_FRAMEWORK
        private mutating func interopNotifications() {
            switch state.interopType {
            case .interopObservation(let observation):
                observation.subprogressBridge?.manager.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed))
                self.observerState = .fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed)
            case .interopMirror:
                break
            default:
                break 
            }
        }
#endif
    }
    
    internal func getProperties<T, E: Error>(
        _ closure: (sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        try state.withLock { state throws(E) -> T in
            let values = Values(state: state)
            let result = try closure(values)
            return result
        }
    }
    
    // MARK: Methods to Read Additional Properties of Subtree with ProgressManager as root
    
    /// Returns a summary for a custom integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom integer property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the integer property to summarize. Must be a property
    ///   where both the value and summary types are `Int`.
    /// - Returns: An `Int` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Int, P.Summary == Int {
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        if property.self == ProgressManager.Properties.TotalFileCount.self {
            return getUpdatedFileCount(type: .total)
        } else if property.self == ProgressManager.Properties.CompletedFileCount.self {
            return getUpdatedFileCount(type: .completed)
        } else {
            return getUpdatedIntSummary(property: MetatypeWrapper(property))
        }
    }
    
    /// Returns a summary for a custom unsigned integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom integer property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the integer property to summarize. Must be a property
    ///   where both the value and summary types are `UInt64`.
    /// - Returns: An `UInt64` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == UInt64, P.Summary == UInt64 {
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        if property.self == ProgressManager.Properties.TotalByteCount.self {
            return getUpdatedByteCount(type: .total)
        } else if property.self == ProgressManager.Properties.CompletedByteCount.self {
            return getUpdatedByteCount(type: .completed)
        } else {
            return getUpdatedUInt64Summary(property: MetatypeWrapper(property))
        }
    }
    
    /// Returns a summary for a custom double property across the progress subtree.
    ///
    /// This method aggregates the values of a custom double property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the double property to summarize. Must be a property
    ///   where both the value and summary types are `Double`.
    /// - Returns: A `Double` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Double, P.Summary == Double {
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        return getUpdatedDoubleSummary(property: MetatypeWrapper(property))
    }
    
    /// Returns a summary for a custom string property across the progress subtree.
    ///
    /// This method aggregates the values of a custom string property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the string property to summarize. Must be a property
    ///   where both the value type is `String?` and the summary type is  `[String?]`.
    /// - Returns: A `[String?]` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == String?, P.Summary == [String?] {
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        return getUpdatedStringSummary(property: MetatypeWrapper(property))
    }
    
    /// Returns a summary for a custom URL property across the progress subtree.
    ///
    /// This method aggregates the values of a custom URL property from this progress manager
    /// and all its children, returning a consolidated summary value as an array of URLs.
    ///
    /// - Parameter property: The type of the URL property to summarize. Must be a property
    ///   where the value type is `URL?` and the summary type is `[URL?]`.
    /// - Returns: A `[URL?]` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == URL?, P.Summary == [URL?] {
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        return getUpdatedURLSummary(property: MetatypeWrapper(property))
    }
    
    /// Returns a summary for a custom UInt64 property across the progress subtree.
    ///
    /// This method aggregates the values of a custom UInt64 property from this progress manager
    /// and all its children, returning a consolidated summary value as an array of UInt64 values.
    ///
    /// - Parameter property: The type of the UInt64 property to summarize. Must be a property
    ///   where the value type is `UInt64` and the summary type is `[UInt64]`.
    /// - Returns: A `[UInt64]` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == UInt64, P.Summary == [UInt64] {
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        if property.self == ProgressManager.Properties.Throughput.self {
            return getUpdatedThroughput()
        } else {
            return getUpdatedUInt64ArraySummary(property: MetatypeWrapper(property))
        }
    }
    
    /// Returns a summary for a custom Duration property across the progress subtree.
    ///
    /// This method aggregates the values of a custom Duration property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the Duration property to summarize. Must be a property
    ///   where the value type is `Duration` and the summary type is `Duration`.
    /// - Returns: A `Duration` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Duration, P.Summary == Duration {
        accessObservation(keyPath: ProgressManager.additionalPropertiesKeyPath.withLock { $0 })
        if property.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
            return getUpdatedEstimatedTimeRemaining()
        } else {
            return getUpdatedDurationSummary(property: MetatypeWrapper(property))
        }
    }
}
