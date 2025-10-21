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

#if canImport(Synchronization)
internal import Synchronization
#endif

@available(FoundationPreview 6.4, *)
extension ProgressManager {

    // MARK: Methods to Read & Write Custom Properties of single ProgressManager node
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
                self.access(keyPath: \.customPropertiesInt)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.TotalFileCount.self {
                    return state.totalFileCount
                } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
                    return state.completedFileCount
                } else {
                    return state.customPropertiesInt[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }
        
        set {
            var parents: [Parent]?
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
                self.withMutation(keyPath: \.customPropertiesInt) {
                    parents = state.withLock { state in
                        guard newValue != state.customPropertiesInt[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.customPropertiesInt[MetatypeWrapper(P.self)] = newValue
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
                self.access(keyPath: \.customPropertiesUInt64)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.TotalByteCount.self {
                    return state.totalByteCount
                } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
                    return state.completedByteCount
                } else {
                    return state.customPropertiesUInt64[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }
        
        set {
            var parents: [Parent]?
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
                self.withMutation(keyPath: \.customPropertiesUInt64) {
                    parents = state.withLock { state in
                        guard newValue != state.customPropertiesUInt64[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.customPropertiesUInt64[MetatypeWrapper(P.self)] = newValue
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
            self.access(keyPath: \.customPropertiesDouble)
            return state.withLock { state in
                return state.customPropertiesDouble[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
        }
        
        set {
            var parents: [Parent]?
            self.withMutation(keyPath: \.customPropertiesDouble) {
                parents = state.withLock { state in
                    guard newValue != state.customPropertiesDouble[MetatypeWrapper(P.self)] else {
                        return nil
                    }
                    state.customPropertiesDouble[MetatypeWrapper(P.self)] = newValue
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
            self.access(keyPath: \.customPropertiesString)
            return state.withLock { state in
                return state.customPropertiesString[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
        }

        set {
            var parents: [Parent]?
            self.withMutation(keyPath: \.customPropertiesString) {
                parents = state.withLock { state in
                    guard newValue != state.customPropertiesString[MetatypeWrapper(P.self)] else {
                        return nil
                    }
                    state.customPropertiesString[MetatypeWrapper(P.self)] = newValue
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
            self.access(keyPath: \.customPropertiesURL)
            return state.withLock { state in
                return state.customPropertiesURL[MetatypeWrapper(P.self)] ?? P.defaultValue
            }
        }

        set {
            var parents: [Parent]?
            self.withMutation(keyPath: \.customPropertiesURL) {
                parents = state.withLock { state in
                    guard newValue != state.customPropertiesURL[MetatypeWrapper(P.self)] else {
                        return nil
                    }
                    state.customPropertiesURL[MetatypeWrapper(P.self)] = newValue
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
                self.access(keyPath: \.customPropertiesUInt64Array)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.Throughput.self {
                    return state.throughput
                } else {
                    return state.customPropertiesUInt64Array[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }

        set {
            var parents: [Parent]?
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
                self.withMutation(keyPath: \.customPropertiesUInt64Array) {
                    parents = state.withLock { state in
                        guard newValue != state.customPropertiesUInt64Array[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.customPropertiesUInt64Array[MetatypeWrapper(P.self)] = newValue
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
                self.access(keyPath: \.customPropertiesDuration)
            }
            return state.withLock { state in
                if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
                    return state.estimatedTimeRemaining
                } else {
                    return state.customPropertiesDuration[MetatypeWrapper(P.self)] ?? P.defaultValue
                }
            }
        }

        set {
            var parents: [Parent]?
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
                self.withMutation(keyPath: \.customPropertiesDuration) {
                    parents = state.withLock { state in
                        guard newValue != state.customPropertiesDuration[MetatypeWrapper(P.self)] else {
                            return nil
                        }
                        state.customPropertiesDuration[MetatypeWrapper(P.self)] = newValue
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
    
    // MARK: Methods to Read Custom Properties of Subtree with ProgressManager as root
    

    /// Returns a summary for a custom integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom integer property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the integer property to summarize. Must be a property
    ///   where both the value and summary types are `Int`.
    /// - Returns: An `Int` summary value for the specified property.
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P.Value == Int, P.Summary == Int {
        if P.self == ProgressManager.Properties.TotalFileCount.self {
            self.access(keyPath: \.totalFileCount)
            self.access(keyPath: \.totalFileCountSummary)
            self.didSet(keyPath: \.totalFileCountSummary)
            return updatedFileCount(type: .total)
        } else if P.self == ProgressManager.Properties.CompletedFileCount.self {
            self.access(keyPath: \.completedFileCount)
            self.access(keyPath: \.completedFileCountSummary)
            self.didSet(keyPath: \.completedFileCountSummary)
            return updatedFileCount(type: .completed)
        } else {
            self.access(keyPath: \.customPropertiesInt)
            self.access(keyPath: \.customPropertiesIntSummary)
            self.didSet(keyPath: \.customPropertiesIntSummary)
            return updatedIntSummary(property: MetatypeWrapper(P.self))
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
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P.Value == UInt64, P.Summary == UInt64 {
        if P.self == ProgressManager.Properties.TotalByteCount.self {
            self.access(keyPath: \.totalByteCount)
            self.access(keyPath: \.totalByteCountSummary)
            self.didSet(keyPath: \.totalByteCountSummary)
            return updatedByteCount(type: .total)
        } else if P.self == ProgressManager.Properties.CompletedByteCount.self {
            self.access(keyPath: \.completedByteCount)
            self.access(keyPath: \.completedByteCountSummary)
            self.didSet(keyPath: \.completedByteCountSummary)
            return updatedByteCount(type: .completed)
        } else {
            self.access(keyPath: \.customPropertiesUInt64)
            self.access(keyPath: \.customPropertiesUInt64Summary)
            self.didSet(keyPath: \.customPropertiesUInt64Summary)
            return updatedUInt64Summary(property: MetatypeWrapper(P.self))
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
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P.Value == Double, P.Summary == Double {
        self.access(keyPath: \.customPropertiesDouble)
        self.access(keyPath: \.customPropertiesDoubleSummary)
        self.didSet(keyPath: \.customPropertiesDoubleSummary)
        return updatedDoubleSummary(property: MetatypeWrapper(P.self))
    }
    
    /// Returns a summary for a custom string property across the progress subtree.
    ///
    /// This method aggregates the values of a custom string property from this progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the string property to summarize. Must be a property
    ///   where both the value type is `String?` and the summary type is  `[String?]`.
    /// - Returns: A `[String?]` summary value for the specified property.
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P.Value == String?, P.Summary == [String?] {
        self.access(keyPath: \.customPropertiesString)
        self.access(keyPath: \.customPropertiesStringSummary)
        self.didSet(keyPath: \.customPropertiesStringSummary)
        return updatedStringSummary(property: MetatypeWrapper(P.self))
    }
    
    /// Returns a summary for a custom URL property across the progress subtree.
    ///
    /// This method aggregates the values of a custom URL property from this progress manager
    /// and all its children, returning a consolidated summary value as an array of URLs.
    ///
    /// - Parameter property: The type of the URL property to summarize. Must be a property
    ///   where the value type is `URL?` and the summary type is `[URL?]`.
    /// - Returns: A `[URL?]` summary value for the specified property.
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P.Value == URL?, P.Summary == [URL?] {
        self.access(keyPath: \.customPropertiesURL)
        self.access(keyPath: \.customPropertiesURLSummary)
        self.didSet(keyPath: \.customPropertiesURLSummary)
        return updatedURLSummary(property: MetatypeWrapper(P.self))
    }
    
    /// Returns a summary for a custom unsigned integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom unsigned integer property from this progress manager
    /// and all its children, returning a consolidated summary value as an array of UInt64 values.
    ///
    /// - Parameter property: The type of the unsigned integer property to summarize. Must be a property
    ///   where the value type is `UInt64` and the summary type is `[UInt64]`.
    /// - Returns: A `[UInt64]` summary value for the specified property.
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P.Value == UInt64, P.Summary == [UInt64] {
        if P.self == ProgressManager.Properties.Throughput.self {
            self.access(keyPath: \.throughput)
            self.access(keyPath: \.throughputSummary)
            self.didSet(keyPath: \.throughputSummary)
            return updatedThroughput()
        } else {
            self.access(keyPath: \.customPropertiesUInt64Array)
            self.access(keyPath: \.customPropertiesUInt64ArraySummary)
            self.didSet(keyPath: \.customPropertiesUInt64ArraySummary)
            return updatedUInt64ArraySummary(property: MetatypeWrapper(P.self))
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
    public func summary<P: Property>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P.Value == Duration, P.Summary == Duration {
        if P.self == ProgressManager.Properties.EstimatedTimeRemaining.self {
            self.access(keyPath: \.estimatedTimeRemaining)
            self.access(keyPath: \.estimatedTimeRemainingSummary)
            self.didSet(keyPath: \.estimatedTimeRemainingSummary)
            return updatedEstimatedTimeRemaining()
        } else {
            self.access(keyPath: \.customPropertiesDuration)
            self.access(keyPath: \.customPropertiesDurationSummary)
            self.didSet(keyPath: \.customPropertiesDurationSummary)
            return updatedDurationSummary(property: MetatypeWrapper(P.self))
        }
    }
}
