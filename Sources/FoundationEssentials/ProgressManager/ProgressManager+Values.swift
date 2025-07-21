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

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    /// A container that holds values for properties that specify information on progress.
    @dynamicMemberLookup
    public struct Values : Sendable {
        //TODO: rdar://149225947 Non-escapable conformance
        var state: State
        
        var fractionalCountDirty = false
        var totalFileCountDirty = false
        var completedFileCountDirty = false
        var totalByteCountDirty = false
        var completedByteCountDirty = false
        var throughputDirty = false
        var estimatedTimeRemainingDirty = false
        var dirtyProperties: [any Property.Type] = []
        var dirtyPropertiesInt: [any Property.Type] = []
        var dirtyPropertiesDouble: [any Property.Type] = []
        var dirtyPropertiesString: [any Property.Type] = []
        var observerState: ObserverState?
                
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
                
                state.progressParentProgressManagerChildMessenger?.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed))
                
                observerState = .fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed)
                
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
                
                state.progressParentProgressManagerChildMessenger?.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed))
                
                observerState = .fractionUpdated(totalCount: state.selfFraction.total ?? 0, completedCount: state.selfFraction.completed)

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
        
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P.Value == Int {
            get {
                return state.propertiesInt[AnyMetatypeWrapper(metatype: P.self)] ?? P.self.defaultValue
            }
            
            set {
                guard newValue != state.propertiesInt[AnyMetatypeWrapper(metatype: P.self)] else {
                    return
                }
                
                state.propertiesInt[AnyMetatypeWrapper(metatype: P.self)] = newValue
                
                dirtyPropertiesInt.append(P.self)
            }
        }
        
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Double where P.Value == Double {
            get {
                return state.propertiesDouble[AnyMetatypeWrapper(metatype: P.self)] ?? P.self.defaultValue
            }
            
            set {
                guard newValue != state.propertiesDouble[AnyMetatypeWrapper(metatype: P.self)] else {
                    return
                }
                
                state.propertiesDouble[AnyMetatypeWrapper(metatype: P.self)] = newValue
                
                dirtyPropertiesDouble.append(P.self)
            }
        }
        
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> String where P.Value == String {
            get {
                return state.propertiesString[AnyMetatypeWrapper(metatype: P.self)] ?? P.self.defaultValue
            }
            
            set {
                guard newValue != state.propertiesString[AnyMetatypeWrapper(metatype: P.self)] else {
                    return
                }
                
                state.propertiesString[AnyMetatypeWrapper(metatype: P.self)] = newValue
                
                dirtyPropertiesString.append(P.self)
            }
        }
        
        /// Returns a property value that a key path indicates. If value is not defined, returns property's `defaultValue`.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value {
            get {
                return state.properties[AnyMetatypeWrapper(metatype: P.self)] as? P.Value ?? P.self.defaultValue
            }
            
            set {
                guard newValue != state.properties[AnyMetatypeWrapper(metatype: P.self)] as? P.Value else {
                    return
                }
                
                state.properties[AnyMetatypeWrapper(metatype: P.self)] = newValue
                
                dirtyProperties.append(P.self)
            }
        }
    }
}
