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
        internal var state: State
        
        internal var fractionalCountDirty = false
        internal var totalFileCountDirty = false
        internal var completedFileCountDirty = false
        internal var totalByteCountDirty = false
        internal var completedByteCountDirty = false
        internal var throughputDirty = false
        internal var estimatedTimeRemainingDirty = false
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
    }
}
