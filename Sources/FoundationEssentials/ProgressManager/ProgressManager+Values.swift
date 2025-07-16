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
        var dirtyProperties: [any Property.Type] = []
        var observerState: ObserverState?
        
        let willGetCompletedCount: (@Sendable (inout State) -> (Int))
        
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
                willGetCompletedCount(&state)
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
