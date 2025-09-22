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

@available(FoundationPreview 6.4, *)
extension ProgressManager {
    
    private var totalFileCount: Int {
        return state.withLock { state in
            state.totalFileCount
        }
    }
    
    private var completedFileCount: Int {
        return state.withLock { state in
            state.completedFileCount
        }
    }
    
    private var totalByteCount: UInt64 {
        return state.withLock { state in
            state.totalByteCount
        }
    }
    
    private var completedByteCount: UInt64 {
        return state.withLock { state in
            state.completedByteCount
        }
    }
    
    private var estimatedTimeRemaining: Duration {
        return state.withLock { state in
            state.estimatedTimeRemaining
        }
    }
    
    private var throughput: UInt64 {
        return state.withLock { state in
            state.throughput
        }
    }

    // MARK: Methods to Read & Write Additional Properties of single ProgressManager node
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
                self.access(keyPath: \.totalFileCount)
            } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
                self.access(keyPath: \.completedFileCount)
            } else {
                self.access(keyPath: \.additionalPropertiesSink)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.TotalFileCount.self {
                    return state.totalFileCount
                } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
                    return state.completedFileCount
                } else {
                    return state.propertiesInt[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }
        
        set {
            var parents: [ParentState]?
            if P.self == ProgressManager.Properties.TotalFileCount.self {
                self.withMutation(keyPath: \.totalFileCount) {
                    parents = state.withLock { state in
                        guard newValue != state.totalFileCount else {
                            return nil
                        }
                        state.totalFileCount = newValue
                        return state.parents
                    }
                }
            } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
                self.withMutation(keyPath: \.completedFileCount) {
                    parents = state.withLock { state in
                        guard newValue != state.completedFileCount else {
                            return nil
                        }
                        state.completedFileCount = newValue
                        return state.parents
                    }
                }
            } else {
                self.withMutation(keyPath: \.additionalPropertiesSink) {
                    parents = state.withLock { state in
                        guard newValue != state.propertiesInt[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.propertiesInt[MetatypeWrapper(P.self)] = newValue
                        return state.parents
                    }
                }
            }
            
            if let parents = parents {
                if P.self == ProgressManager.Properties.TotalFileCount.self {
                    markSelfDirty(property: ProgressManager.Properties.TotalFileCount.self, parents: parents)
                } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
                    markSelfDirty(property: ProgressManager.Properties.CompletedFileCount.self, parents: parents)
                } else {
                    markSelfDirty(property: MetatypeWrapper(P.self), parents: parents)
                }
            }
        }
    }
    
    /// Gets or sets custom unsigned integer properties.
    ///
    /// This subscript provides read-write access to custom progress properties where both the value
    /// and summary types are `UInt64`. If the property has not been set, the getter returns the
    /// property's default value.
    ///
    /// - Parameter key: A key path to the custom unsigned integer property type.
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == UInt64 {
        get {
            if P.self == ProgressManager.Properties.TotalByteCount.self {
                self.access(keyPath: \.totalByteCount)
            } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
                self.access(keyPath: \.completedByteCount)
            } else {
                self.access(keyPath: \.additionalPropertiesSink)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.TotalByteCount.self {
                    return state.totalByteCount
                } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
                    return state.completedByteCount
                } else {
                    return state.propertiesUInt64[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }
        
        set {
            var parents: [ParentState]?
            if P.self == ProgressManager.Properties.TotalByteCount.self {
                self.withMutation(keyPath: \.totalByteCount) {
                    parents = state.withLock { state in
                        guard newValue != state.totalByteCount else {
                            return nil
                        }
                        state.totalByteCount = newValue
                        return state.parents
                    }
                }
            } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
                self.withMutation(keyPath: \.completedByteCount) {
                    parents = state.withLock { state in
                        guard newValue != state.completedByteCount else {
                            return nil
                        }
                        state.completedByteCount = newValue
                        return state.parents
                    }
                }
            } else {
                self.withMutation(keyPath: \.additionalPropertiesSink) {
                    parents = state.withLock { state in
                        guard newValue != state.propertiesUInt64[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.propertiesUInt64[MetatypeWrapper(P.self)] = newValue
                        return state.parents
                    }
                }
            }
            
            if let parents = parents {
                if P.self == ProgressManager.Properties.TotalByteCount.self {
                    markSelfDirty(property: ProgressManager.Properties.TotalByteCount.self, parents: parents)
                } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
                    markSelfDirty(property: ProgressManager.Properties.CompletedByteCount.self, parents: parents)
                } else {
                    markSelfDirty(property: MetatypeWrapper(P.self), parents: parents)
                }
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
            self.access(keyPath: \.additionalPropertiesSink)
            return state.withLock { state in
                return state.propertiesDouble[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
        }
        
        set {
            var parents: [ParentState]?
            self.withMutation(keyPath: \.additionalPropertiesSink) {
                parents = state.withLock { state in
                    guard newValue != state.propertiesDouble[MetatypeWrapper(P.self)] else {
                        return nil
                    }
                    state.propertiesDouble[MetatypeWrapper(P.self)] = newValue
                    return state.parents
                }
            }
            
            if let parents = parents {
                markSelfDirty(property: MetatypeWrapper(P.self), parents: parents)
            }
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
            self.access(keyPath: \.additionalPropertiesSink)
            return state.withLock { state in
                return state.propertiesString[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
        }

        set {
            var parents: [ParentState]?
            self.withMutation(keyPath: \.additionalPropertiesSink) {
                parents = state.withLock { state in
                    guard newValue != state.propertiesString[MetatypeWrapper(P.self)] else {
                        return nil
                    }
                    state.propertiesString[MetatypeWrapper(P.self)] = newValue
                    return state.parents
                }
            }
            
            if let parents = parents {
                markSelfDirty(property: MetatypeWrapper(P.self), parents: parents)
            }
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
            self.access(keyPath: \.additionalPropertiesSink)
            return state.withLock { state in
                return state.propertiesURL[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
        }

        set {
            var parents: [ParentState]?
            self.withMutation(keyPath: \.additionalPropertiesSink) {
                parents = state.withLock { state in
                    guard newValue != state.propertiesURL[MetatypeWrapper(P.self)] else {
                        return nil
                    }
                    state.propertiesURL[MetatypeWrapper(P.self)] = newValue
                    return state.parents
                }
            }
            
            if let parents = parents {
                markSelfDirty(property: MetatypeWrapper(P.self), parents: parents)
            }
        }
    }
    
    /// Gets or sets custom unsigned integer properties.
    ///
    /// This subscript provides read-write access to custom progress properties where the value
    /// type is `UInt64` and the summary type is `[UInt64]`. If the property has not been set,
    /// the getter returns the property's default value.
    ///
    /// - Parameter key: A key path to the custom unsigned integer property type.
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P.Value == UInt64, P.Summary == [UInt64] {
        get {
            if P.self == ProgressManager.Properties.Throughput.self {
                self.access(keyPath: \.throughput)
            } else {
                self.access(keyPath: \.additionalPropertiesSink)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.Throughput.self {
                    return state.throughput
                } else {
                    return state.propertiesUInt64Array[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }

        set {
            var parents: [ParentState]?
            if P.self == ProgressManager.Properties.Throughput.self {
                self.withMutation(keyPath: \.throughput) {
                    parents = state.withLock { state in
                        guard newValue != state.throughput else {
                            return nil
                        }
                        state.throughput = newValue
                        return state.parents
                    }
                }
            } else {
                self.withMutation(keyPath: \.additionalPropertiesSink) {
                    parents = state.withLock { state in
                        guard newValue != state.propertiesUInt64Array[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.propertiesUInt64Array[MetatypeWrapper(P.self)] = newValue
                        return state.parents
                    }
                }
            }
            
            if let parents = parents {
                if P.self == ProgressManager.Properties.Throughput.self {
                    markSelfDirty(property: ProgressManager.Properties.Throughput.self, parents: parents)
                } else {
                    markSelfDirty(property: MetatypeWrapper(P.self), parents: parents)
                }
            }
        }
    }
    
    /// Gets or sets custom duration properties.
    ///
    /// This subscript provides read-write access to custom progress properties where the value
    /// type is `Duration` and the summary type is `Duration`. If the property has not been set,
    /// the getter returns the property's default value.
    ///
    /// - Parameter key: A key path to the custom duration property type.
    public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Duration where P.Value == Duration, P.Summary == Duration {
        get {
            if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
                self.access(keyPath: \.estimatedTimeRemaining)
            } else {
                self.access(keyPath: \.additionalPropertiesSink)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
                    return state.estimatedTimeRemaining
                } else {
                    return state.propertiesDuration[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }

        set {
            var parents: [ParentState]?
            if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
                self.withMutation(keyPath: \.estimatedTimeRemaining) {
                    parents = state.withLock { state in
                        guard newValue != state.estimatedTimeRemaining else {
                            return nil
                        }
                        state.estimatedTimeRemaining = newValue
                        return state.parents
                    }
                }
            } else {
                self.withMutation(keyPath: \.additionalPropertiesSink) {
                    parents = state.withLock { state in
                        guard newValue != state.propertiesDuration[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.propertiesDuration[MetatypeWrapper(P.self)] = newValue
                        return state.parents
                    }
                }
            }
            
            if let parents = parents {
                if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
                    markSelfDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.self, parents: parents)
                } else {
                    markSelfDirty(property: MetatypeWrapper(P.self), parents: parents)
                }
            }
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
        if property.self == ProgressManager.Properties.TotalFileCount.self {
            self.access(keyPath: \.totalFileCount)
            self.access(keyPath: \.totalFileCountSummary)
            self.didSet(keyPath: \.totalFileCountSummary)
            return updatedFileCount(type: .total)
        } else if property.self == ProgressManager.Properties.CompletedFileCount.self {
            self.access(keyPath: \.completedFileCount)
            self.access(keyPath: \.completedFileCountSummary)
            self.didSet(keyPath: \.completedFileCountSummary)
            return updatedFileCount(type: .completed)
        } else {
            self.access(keyPath: \.additionalPropertiesSink)
            self.access(keyPath: \.additionalPropertiesSummarySink)
            self.didSet(keyPath: \.additionalPropertiesSummarySink)
            return updatedIntSummary(property: MetatypeWrapper(property))
        }
    }
    
    /// Returns a summary for a custom unsigned integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom unsigned integer property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the unsigned integer property to summarize. Must be a property
    ///   where both the value and summary types are `UInt64`.
    /// - Returns: An `UInt64` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == UInt64, P.Summary == UInt64 {
        if property.self == ProgressManager.Properties.TotalByteCount.self {
            self.access(keyPath: \.totalByteCount)
            self.access(keyPath: \.totalByteCountSummary)
            self.didSet(keyPath: \.totalByteCountSummary)
            return updatedByteCount(type: .total)
        } else if property.self == ProgressManager.Properties.CompletedByteCount.self {
            self.access(keyPath: \.completedByteCount)
            self.access(keyPath: \.completedByteCountSummary)
            self.didSet(keyPath: \.completedByteCountSummary)
            return updatedByteCount(type: .completed)
        } else {
            self.access(keyPath: \.additionalPropertiesSink)
            self.access(keyPath: \.additionalPropertiesSummarySink)
            self.didSet(keyPath: \.additionalPropertiesSummarySink)
            return updatedUInt64Summary(property: MetatypeWrapper(property))
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
        self.access(keyPath: \.additionalPropertiesSink)
        self.access(keyPath: \.additionalPropertiesSummarySink)
        self.didSet(keyPath: \.additionalPropertiesSummarySink)
        return updatedDoubleSummary(property: MetatypeWrapper(property))
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
        self.access(keyPath: \.additionalPropertiesSink)
        self.access(keyPath: \.additionalPropertiesSummarySink)
        self.didSet(keyPath: \.additionalPropertiesSummarySink)
        return updatedStringSummary(property: MetatypeWrapper(property))
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
        self.access(keyPath: \.additionalPropertiesSink)
        self.access(keyPath: \.additionalPropertiesSummarySink)
        self.didSet(keyPath: \.additionalPropertiesSummarySink)
        return updatedURLSummary(property: MetatypeWrapper(property))
    }
    
    /// Returns a summary for a custom unsigned integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom unsigned integer property from this progress manager
    /// and all its children, returning a consolidated summary value as an array of UInt64 values.
    ///
    /// - Parameter property: The type of the unsigned integer property to summarize. Must be a property
    ///   where the value type is `UInt64` and the summary type is `[UInt64]`.
    /// - Returns: A `[UInt64]` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == UInt64, P.Summary == [UInt64] {
        if property.self == ProgressManager.Properties.Throughput.self {
            self.access(keyPath: \.throughput)
            self.access(keyPath: \.throughputSummary)
            self.didSet(keyPath: \.throughputSummary)
            return updatedThroughput()
        } else {
            self.access(keyPath: \.additionalPropertiesSink)
            self.access(keyPath: \.additionalPropertiesSummarySink)
            self.didSet(keyPath: \.additionalPropertiesSummarySink)
            return updatedUInt64ArraySummary(property: MetatypeWrapper(property))
        }
    }
    
    /// Returns a summary for a custom duration property across the progress subtree.
    ///
    /// This method aggregates the values of a custom duration property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the duration property to summarize. Must be a property
    ///   where the value type is `Duration` and the summary type is `Duration`.
    /// - Returns: A `Duration` summary value for the specified property.
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Value == Duration, P.Summary == Duration {
        if property.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
            self.access(keyPath: \.estimatedTimeRemaining)
            self.access(keyPath: \.estimatedTimeRemainingSummary)
            self.didSet(keyPath: \.estimatedTimeRemainingSummary)
            return updatedEstimatedTimeRemaining()
        } else {
            self.access(keyPath: \.additionalPropertiesSink)
            self.access(keyPath: \.additionalPropertiesSummarySink)
            self.didSet(keyPath: \.additionalPropertiesSummarySink)
            return updatedDurationSummary(property: MetatypeWrapper(property))
        }
    }
}
