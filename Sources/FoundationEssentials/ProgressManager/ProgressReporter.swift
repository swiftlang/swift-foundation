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

import Observation

/// ProgressReporter is a wrapper for ProgressManager that carries information about ProgressManager.
///
/// It is read-only and can be added as a child of another ProgressManager.
@available(FoundationPreview 6.4, *)
@dynamicMemberLookup
@Observable public final class ProgressReporter: Sendable, Hashable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    
    public typealias Property = ProgressManager.Property
    
    /// The total units of work.
    public var totalCount: Int? {
        manager.totalCount
    }
    
    /// The completed units of work.
    /// If `self` is indeterminate, the value will be 0.
    public var completedCount: Int {
        manager.completedCount
    }
    
    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.
    public var fractionCompleted: Double {
        manager.fractionCompleted
    }
    
    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool {
        manager.isIndeterminate
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        manager.isFinished
    }
    
    /// A textual representation of the progress reporter.
    /// 
    /// This property provides a comprehensive description including the class name, object identifier,
    /// underlying progress manager details, and various progress metrics and properties.
    public var description: String {
        return """
        Class Name: ProgressReporter
        Object Identifier: \(ObjectIdentifier(self))
        progressManager: \(manager)
        totalCount: \(String(describing: totalCount))
        completedCount: \(completedCount)
        fractionCompleted: \(fractionCompleted)
        isIndeterminate: \(isIndeterminate)
        isFinished: \(isFinished)
        totalFileCount: \(summary(of: ProgressManager.Properties.TotalFileCount.self))
        completedFileCount: \(summary(of: ProgressManager.Properties.CompletedFileCount.self))
        totalByteCount: \(summary(of: ProgressManager.Properties.TotalByteCount.self))
        completedByteCount: \(summary(of: ProgressManager.Properties.CompletedByteCount.self))
        throughput: \(summary(of: ProgressManager.Properties.Throughput.self))
        estimatedTimeRemaining: \(summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self))
        """
    }
    
    /// A textual representation of the progress reporter suitable for debugging.
    /// 
    /// This property returns the same value as `description`, providing detailed information
    /// about the progress reporter's state for debugging purposes.
    public var debugDescription: String {
        return self.description
    }
    
    /// Returns a summary for the specified integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom integer property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the integer property to summarize. Must be a property
    ///   where both the value and summary types are `Int`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> Int where P.Value == Int, P.Summary == Int {
        manager.summary(of: property)
    }
    
    /// Returns a summary for the specified unsigned integer property across the progress subtree.
    ///
    /// This method aggregates the values of a custom unsigned integer property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the unsigned property to summarize. Must be a property
    ///   where both the value and summary types are `UInt64`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> UInt64 where P.Value == UInt64, P.Summary == UInt64 {
        manager.summary(of: property)
    }
    
    /// Returns a summary for the specified double property across the progress subtree.
    ///
    /// This method aggregates the values of a custom double property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the double property to summarize. Must be a property
    ///   where both the value and summary types are `Double`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> Double where P.Value == Double, P.Summary == Double {
        manager.summary(of: property)
    }
    
    /// Returns a summary for the specified string property across the progress subtree.
    ///
    /// This method aggregates the values of a custom string property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the string property to summarize. Must be a property
    ///   where both the value and summary types are `String`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> [String?] where P.Value == String?, P.Summary == [String?] {
        return manager.summary(of: property)
    }
    
    /// Returns a summary for the specified URL property across the progress subtree.
    ///
    /// This method aggregates the values of a custom URL property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the URL property to summarize. Must be a property
    ///   where both the value and summary types are `URL?` and `[URL?]` respectively.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> [URL?] where P.Value == URL?, P.Summary == [URL?] {
        return manager.summary(of: property)
    }
    
    /// Returns a summary for the specified unsigned integer array property across the progress subtree.
    ///
    /// This method aggregates the values of a custom unsigned integer property from the underlying progress manager
    /// and all its children, returning a consolidated summary value as an array.
    ///
    /// - Parameter property: The type of the unsigned integer property to summarize. Must be a property
    ///   where the value type is `UInt64` and the summary type is `[UInt64]`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> [UInt64] where P.Value == UInt64, P.Summary == [UInt64] {
        return manager.summary(of: property)
    }
    
    /// Returns a summary for the specified duration property across the progress subtree.
    ///
    /// This method aggregates the values of a custom duration property from the underlying progress manager
    /// and all its children, returning a consolidated summary value.
    ///
    /// - Parameter property: The type of the duration property to summarize. Must be a property
    ///   where both the value and summary types are `Duration`.
    /// - Returns: The aggregated summary value for the specified property across the entire subtree.
    public func summary<P: Property>(of property: P.Type) -> Duration where P.Value == Duration, P.Summary == Duration {
        return manager.summary(of: property)
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
            manager[dynamicMember: key]
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
            manager[dynamicMember: key]
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
            manager[dynamicMember: key]
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
            manager[dynamicMember: key]
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
            manager[dynamicMember: key]
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
            manager[dynamicMember: key]
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
            manager[dynamicMember: key]
        }
    }
    
    internal let manager: ProgressManager
    
    internal init(manager: ProgressManager) {
        self.manager = manager
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    public static func == (lhs: ProgressReporter, rhs: ProgressReporter) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}
