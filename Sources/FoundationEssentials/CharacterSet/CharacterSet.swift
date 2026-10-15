//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@_exported import Foundation // Clang module
import CoreFoundation
internal import _ForSwiftFoundation
internal import CoreFoundation_Private.CFURL

private func _utfRangeToCFRange(_ inRange : Range<Unicode.Scalar>) -> CFRange {
    return CFRange(
        location: Int(inRange.lowerBound.value),
        length: Int(inRange.upperBound.value - inRange.lowerBound.value))
}

private func _utfRangeToCFRange(_ inRange : ClosedRange<Unicode.Scalar>) -> CFRange {
    return CFRange(
        location: Int(inRange.lowerBound.value),
        length: Int(inRange.upperBound.value - inRange.lowerBound.value + 1))
}
#endif

// MARK: -

// NOTE: older overlays called this class _CharacterSetStorage.
// The two must coexist without a conflicting ObjC class name, so it
// was renamed. The old name must not be used in the new runtime.
private final class __CharacterSetStorage : Hashable, @unchecked Sendable {
    enum Backing {
        #if FOUNDATION_FRAMEWORK
        case immutable(CFCharacterSet)
        case mutable(CFMutableCharacterSet)
        #endif
        case swift(_CharacterSet)
    }
    
    var _backing: Backing
   
    #if FOUNDATION_FRAMEWORK
    @nonobjc
    init(immutableReference r: CFCharacterSet) {
        _backing = .immutable(r)
    }

    @nonobjc
    init(mutableReference r: CFMutableCharacterSet) {
        _backing = .mutable(r)
    }
    #endif
    
    @nonobjc
    init(swift s: _CharacterSet) {
        _backing = .swift(s)
    }
    
    // MARK: -
    
    func hash(into hasher: inout Hasher) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            hasher.combine(CFHash(cs))
        case .mutable(let cs):
            hasher.combine(CFHash(cs))
        #endif
        case .swift(let cs):
            cs.hash(into: &hasher)
        }
    }

    static func ==(lhs: __CharacterSetStorage, rhs: __CharacterSetStorage) -> Bool {
        switch (lhs._backing, rhs._backing) {
        #if FOUNDATION_FRAMEWORK
        case (.immutable(let cs1), .immutable(let cs2)):
            return CFEqual(cs1, cs2)
        case (.immutable(let cs1), .mutable(let cs2)):
            return CFEqual(cs1, cs2)
        case (.mutable(let cs1), .immutable(let cs2)):
            return CFEqual(cs1, cs2)
        case (.mutable(let cs1), .mutable(let cs2)):
            return CFEqual(cs1, cs2)
        case (.swift(let cs1), .immutable(let cs2)):
            if let swiftCs2 = cs2._backingSwiftCharacterSet {
                return cs1 == swiftCs2
            } else {
                return cs1.bitmapRepresentation == CFCharacterSetCreateBitmapRepresentation(nil, cs2) as Data
            }
        case (.immutable(let cs1), .swift(let cs2)):
            if let swiftCs1 = cs1._backingSwiftCharacterSet {
                return swiftCs1 == cs2
            } else {
                return CFCharacterSetCreateBitmapRepresentation(nil, cs1) as Data == cs2.bitmapRepresentation
            }
        case (.swift(let cs1), .mutable(let cs2)):
            if let swiftCs2 = cs2._backingSwiftCharacterSet {
                return cs1 == swiftCs2
            } else {
                return cs1.bitmapRepresentation == CFCharacterSetCreateBitmapRepresentation(nil, cs2) as Data
            }
        case (.mutable(let cs1), .swift(let cs2)):
            if let swiftCs1 = cs1._backingSwiftCharacterSet {
                return swiftCs1 == cs2
            } else {
                return CFCharacterSetCreateBitmapRepresentation(nil, cs1) as Data == cs2.bitmapRepresentation
            }
        #endif
        case (.swift(let cs1), .swift(let cs2)):
            return cs1 == cs2
        }
    }
    
    // MARK: -
    
    func mutableCopy() -> __CharacterSetStorage {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return __CharacterSetStorage(mutableReference: CFCharacterSetCreateMutableCopy(nil, cs))
        case .mutable(let cs):
            return __CharacterSetStorage(mutableReference: CFCharacterSetCreateMutableCopy(nil, cs))
        #endif
        case .swift(let cs):
            return __CharacterSetStorage(swift: cs.copy())
        }
    }

    
    // MARK: Immutable Functions
    
    var bitmapRepresentation: Data {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return CFCharacterSetCreateBitmapRepresentation(nil, cs) as Data
        case .mutable(let cs):
            return CFCharacterSetCreateBitmapRepresentation(nil, cs) as Data
        #endif
        case .swift(let cs):
            return cs.bitmapRepresentation
        }
    }
    
    func hasMember(inPlane plane: UInt8) -> Bool {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return CFCharacterSetHasMemberInPlane(cs, CFIndex(plane))
        case .mutable(let cs):
            return CFCharacterSetHasMemberInPlane(cs, CFIndex(plane))
        #endif
        case .swift(let cs):
            return cs.hasMember(inPlane: plane)
        }
    }
    
    // MARK: Mutable functions

    func insert(charactersIn range: Range<Unicode.Scalar>) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            CFCharacterSetAddCharactersInRange(r, _utfRangeToCFRange(range))
            _backing = .mutable(r)
        case .mutable(let cs):
            CFCharacterSetAddCharactersInRange(cs, _utfRangeToCFRange(range))
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            cs.insert(charactersIn: range)
            _backing = .swift(cs)
        }
    }

    func insert(charactersIn range: ClosedRange<Unicode.Scalar>) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            CFCharacterSetAddCharactersInRange(r, _utfRangeToCFRange(range))
            _backing = .mutable(r)
        case .mutable(let cs):
            CFCharacterSetAddCharactersInRange(cs, _utfRangeToCFRange(range))
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            cs.insert(charactersIn: range)
            _backing = .swift(cs)
        }
    }

    func remove(charactersIn range: Range<Unicode.Scalar>) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            CFCharacterSetRemoveCharactersInRange(r, _utfRangeToCFRange(range))
            _backing = .mutable(r)
        case .mutable(let cs):
            CFCharacterSetRemoveCharactersInRange(cs, _utfRangeToCFRange(range))
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            cs.remove(charactersIn: range)
            _backing = .swift(cs)
        }
    }

    func remove(charactersIn range: ClosedRange<Unicode.Scalar>) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            CFCharacterSetRemoveCharactersInRange(r, _utfRangeToCFRange(range))
            _backing = .mutable(r)
        case .mutable(let cs):
            CFCharacterSetRemoveCharactersInRange(cs, _utfRangeToCFRange(range))
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            cs.remove(charactersIn: range)
            _backing = .swift(cs)
        }
    }

    func insert(charactersIn string: String) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            CFCharacterSetAddCharactersInString(r, string as CFString)
            _backing = .mutable(r)
        case .mutable(let cs):
            CFCharacterSetAddCharactersInString(cs, string as CFString)
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            cs.insert(charactersIn: string)
            _backing = .swift(cs)
        }
    }

    func remove(charactersIn string: String) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            CFCharacterSetRemoveCharactersInString(r, string as CFString)
            _backing = .mutable(r)
        case .mutable(let cs):
            CFCharacterSetRemoveCharactersInString(cs, string as CFString)
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            _ = cs.remove(charactersIn: string)
            _backing = .swift(cs)
        }
    }

    func invert() {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            CFCharacterSetInvert(r)
            _backing = .mutable(r)
        case .mutable(let cs):
            CFCharacterSetInvert(cs)
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            cs.invert()
            _backing = .swift(cs)
        }
    }

    // -----
    // MARK: -
    // MARK: SetAlgebra

    @discardableResult
    func insert(_ character: Unicode.Scalar) -> (inserted: Bool, memberAfterInsert: Unicode.Scalar) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable, .mutable:
            // NOTE: The old behavior avoids two calls into NSCharacterSet by defaulting to true.
            insert(charactersIn: character...character)
            return (true, character)
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            let result = cs.insert(character)
            _backing = .swift(cs)
            return result
        }

    }

    @discardableResult
    func update(with character: Unicode.Scalar) -> Unicode.Scalar? {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable, .mutable:
            // NOTE: The old behavior avoids two calls into NSCharacterSet by defaulting to true.
            insert(character)
            return character
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            let result = cs.update(with: character)
            _backing = .swift(cs)
            return result
        }

    }

    @discardableResult
    func remove(_ character: Unicode.Scalar) -> Unicode.Scalar? {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable, .mutable:
            // TODO: Add method to CFCharacterSet to do this in one call
            let result : Unicode.Scalar? = contains(character) ? character : nil
            remove(charactersIn: character...character)
            return result
        #endif
        case .swift(var cs):
            _backing = .swift(_CharacterSet())
            if !isKnownUniquelyReferenced(&cs) {
                cs = cs.copy()
            }
            let result = cs.remove(character)
            _backing = .swift(cs)
            return result
        }
    }
    
    func contains(_ member: Unicode.Scalar) -> Bool {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return CFCharacterSetIsLongCharacterMember(cs, member.value)
        case .mutable(let cs):
            return CFCharacterSetIsLongCharacterMember(cs, member.value)
        #endif
        case .swift(let cs):
            return cs.contains(member)
        }
    }
    
    #if FOUNDATION_FRAMEWORK
    // MARK: -
    // Why do these return CharacterSet instead of CharacterSetStorage?
    // We want to keep the knowledge of if the returned value happened to contain a mutable or immutable CFCharacterSet as close to the creation of that instance as possible
    

    // When the underlying collection does not have a method to return new CharacterSets with changes applied, so we will copy and apply here
    private static func _apply(_ lhs : __CharacterSetStorage, _ rhs : __CharacterSetStorage, _ f : (CFMutableCharacterSet, CFCharacterSet) -> ()) -> CharacterSet {
        let copyOfMe : CFMutableCharacterSet
        switch lhs._backing {
        case .immutable(let cs):
            copyOfMe = CFCharacterSetCreateMutableCopy(nil, cs)!
        case .mutable(let cs):
            copyOfMe = CFCharacterSetCreateMutableCopy(nil, cs)!
        case .swift:
            // NOTE: For Swift cases, it will never call into this because it will directly call the corresponding methods in Swift.
            fatalError("The helper method _apply should never be used by native Swift CharacterSet implementation.")
        }
        
        switch rhs._backing {
        case .immutable(let cs):
            f(copyOfMe, cs)
        case .mutable(let cs):
            f(copyOfMe, cs)
        case .swift:
            // NOTE: For Swift cases, it will never call into this because it will directly call the corresponding methods in Swift.
            fatalError("The helper method _apply should never be used by native Swift CharacterSet implementation.")
        }
        
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(mutableReference: copyOfMe))
    }
    
    private func _applyMutation(_ other : __CharacterSetStorage, _ f : (CFMutableCharacterSet, CFCharacterSet) -> ()) {
        switch _backing {
        case .immutable(let cs):
            let r = CFCharacterSetCreateMutableCopy(nil, cs)!
            switch other._backing {
            case .immutable(let otherCs):
                f(r, otherCs)
            case .mutable(let otherCs):
                f(r, otherCs)
            case .swift:
                // NOTE: For Swift cases, it will never call into this because it will directly call the corresponding mutating methods in Swift.
                fatalError("The helper method _applyMutation should never be used by native Swift CharacterSet implementation.")
            }
            _backing = .mutable(r)
        case .mutable(let cs):
            switch other._backing {
            case .immutable(let otherCs):
                f(cs, otherCs)
            case .mutable(let otherCs):
                f(cs, otherCs)
            case .swift:
                // NOTE: For Swift cases, it will never call into this because it will directly call the corresponding mutating methods in Swift.
                fatalError("The helper method _applyMutation should never be used by native Swift CharacterSet implementation.")
            }
        case .swift:
            // NOTE: For Swift cases, it will never call into this because it will directly call the corresponding mutating methods in Swift.
            fatalError("The helper method _apply should never be used by native Swift CharacterSet implementation.")
        }
    }
    
    private static func _apply_swift_mutable(_ selfCs : _CharacterSet, _ otherCs : CFMutableCharacterSet, _ f1 : (_CharacterSet) -> (_CharacterSet)) -> CharacterSet {
        if let swiftOtherCs = otherCs._backingSwiftCharacterSet {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: f1(swiftOtherCs)))
        } else {
            let otherBitmap = CFCharacterSetCreateBitmapRepresentation(nil, otherCs) as Data
            let swiftOtherCs = _CharacterSet(bitmapRepresentation: otherBitmap)
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: f1(swiftOtherCs)))
        }
    }
    
    private static func _apply_swift_immutable(_ selfCs : _CharacterSet, _ otherCs : CFCharacterSet, _ f1 : (_CharacterSet) -> (_CharacterSet)) -> CharacterSet {
        if let swiftOtherCs = otherCs._backingSwiftCharacterSet {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: f1(swiftOtherCs)))
        } else {
            let otherBitmap = CFCharacterSetCreateBitmapRepresentation(nil, otherCs) as Data
            let swiftOtherCs = _CharacterSet(bitmapRepresentation: otherBitmap)
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: f1(swiftOtherCs)))
        }
    }
    
    private static func _applyMutation_swift_mutable(_ selfCs : _CharacterSet, _ otherCs : CFMutableCharacterSet, _ f1 : (_CharacterSet) -> (Bool)) -> _CharacterSet {
        if let swiftOtherCs = otherCs._backingSwiftCharacterSet {
            _ = f1(swiftOtherCs)
        } else {
            let otherBitmap = CFCharacterSetCreateBitmapRepresentation(nil, otherCs) as Data
            let swiftOtherCs = _CharacterSet(bitmapRepresentation: otherBitmap)
            _ = f1(swiftOtherCs)
        }
        return selfCs
    }
    
    private static func _applyMutation_swift_immutable(_ selfCs : _CharacterSet, _ otherCs : CFCharacterSet, _ f1 : (_CharacterSet) -> (Bool)) -> _CharacterSet {
        if let swiftOtherCs = otherCs._backingSwiftCharacterSet {
            _ = f1(swiftOtherCs)
        } else {
            let otherBitmap = CFCharacterSetCreateBitmapRepresentation(nil, otherCs) as Data
            let swiftOtherCs = _CharacterSet(bitmapRepresentation: otherBitmap)
            _ = f1(swiftOtherCs)
        }
        return selfCs
    }
    #endif
    
    var inverted: CharacterSet {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: CFCharacterSetCreateInvertedSet(nil, cs)))
        case .mutable(let cs):
            // Even if input is mutable, the result is immutable
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: CFCharacterSetCreateInvertedSet(nil, cs)))
        #endif
        case .swift(let cs):
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: cs.inverted))
        }
    }

    func union(_ other: __CharacterSetStorage) -> CharacterSet {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable:
            return __CharacterSetStorage._apply(self, other, CFCharacterSetUnion)
        case .mutable:
            return __CharacterSetStorage._apply(self, other, CFCharacterSetUnion)
        #endif
        case .swift(let selfCs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                return __CharacterSetStorage._apply_swift_immutable(selfCs, otherCs, selfCs.union)
            case .mutable(let otherCs):
                return __CharacterSetStorage._apply_swift_mutable(selfCs, otherCs, selfCs.union)
            #endif
            case .swift(let otherCs):
                return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: selfCs.union(otherCs)))
            }
        }
    }
    
    func formUnion(_ other: __CharacterSetStorage) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable:
            return _applyMutation(other, CFCharacterSetUnion)
        case .mutable:
            return _applyMutation(other, CFCharacterSetUnion)
        #endif
        case .swift(let selfCs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                let updatedSelf = __CharacterSetStorage._applyMutation_swift_immutable(selfCs, otherCs, selfCs.formUnion)
                _backing = .swift(updatedSelf)
            case .mutable(let otherCs):
                let updatedSelf = __CharacterSetStorage._applyMutation_swift_mutable(selfCs, otherCs, selfCs.formUnion)
                _backing = .swift(updatedSelf)
            #endif
            case .swift(let otherCs):
                let copy = selfCs.copy()
                copy.formUnion(otherCs)
                _backing = .swift(copy)
            }
        }
    }
    
    func intersection(_ other: __CharacterSetStorage) -> CharacterSet {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable:
            return __CharacterSetStorage._apply(self, other, CFCharacterSetIntersect)
        case .mutable:
            return __CharacterSetStorage._apply(self, other, CFCharacterSetIntersect)
        #endif
        case .swift(let selfCs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                return __CharacterSetStorage._apply_swift_immutable(selfCs, otherCs, selfCs.intersection)
            case .mutable(let otherCs):
                return __CharacterSetStorage._apply_swift_mutable(selfCs, otherCs, selfCs.intersection)
            #endif
            case .swift(let otherCs):
                return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: selfCs.intersection(otherCs)))
            }
        }
    }
    
    func formIntersection(_ other: __CharacterSetStorage) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable:
            _applyMutation(other, CFCharacterSetIntersect)
        case .mutable:
            _applyMutation(other, CFCharacterSetIntersect)
        #endif
        case .swift(let selfCs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                let updatedSelf = __CharacterSetStorage._applyMutation_swift_immutable(selfCs, otherCs, selfCs.formIntersection)
                _backing = .swift(updatedSelf)
            case .mutable(let otherCs):
                let updatedSelf = __CharacterSetStorage._applyMutation_swift_mutable(selfCs, otherCs, selfCs.formIntersection)
                _backing = .swift(updatedSelf)
            #endif
            case .swift(let otherCs):
                let copy = selfCs.copy()
                copy.formIntersection(otherCs)
                _backing = .swift(copy)
            }
        }
    }
    
    func subtracting(_ other: __CharacterSetStorage) -> CharacterSet {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable:
            return intersection(other.inverted._storage)
        case .mutable:
            return intersection(other.inverted._storage)
        #endif
        case .swift(let selfCs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                return __CharacterSetStorage._apply_swift_immutable(selfCs, otherCs, selfCs.subtracting)
            case .mutable(let otherCs):
                return __CharacterSetStorage._apply_swift_mutable(selfCs, otherCs, selfCs.subtracting)
            #endif
            case .swift(let otherCs):
                return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: selfCs.subtracting(otherCs)))
            }
        }
    }
    
    func subtract(_ other: __CharacterSetStorage) {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable:
            _applyMutation(other.inverted._storage, CFCharacterSetIntersect)
        case .mutable:
            _applyMutation(other.inverted._storage, CFCharacterSetIntersect)
        #endif
        case .swift(let selfCs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                let updatedSelf = __CharacterSetStorage._applyMutation_swift_immutable(selfCs, otherCs, selfCs.subtract)
                _backing = .swift(updatedSelf)
            case .mutable(let otherCs):
                let updatedSelf = __CharacterSetStorage._applyMutation_swift_mutable(selfCs, otherCs, selfCs.subtract)
                _backing = .swift(updatedSelf)
            #endif
            case .swift(let otherCs):
                let copy = selfCs.copy()
                copy.subtract(otherCs)
                _backing = .swift(copy)
            }
        }
    }
    
    func symmetricDifference(_ other: __CharacterSetStorage) -> CharacterSet {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable:
            return union(other).subtracting(intersection(other))
        case .mutable:
            return union(other).subtracting(intersection(other))
        #endif
        case .swift(let selfCs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                return __CharacterSetStorage._apply_swift_immutable(selfCs, otherCs, selfCs.symmetricDifference)
            case .mutable(let otherCs):
                return __CharacterSetStorage._apply_swift_mutable(selfCs, otherCs, selfCs.symmetricDifference)
            #endif
            case .swift(let otherCs):
                return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: selfCs.symmetricDifference(otherCs)))
            }
        }
        
    }
    
    func formSymmetricDifference(_ other: __CharacterSetStorage) {
        // This feels like cheating
        _backing = symmetricDifference(other)._storage._backing
    }
    
    func isSuperset(of other: __CharacterSetStorage) -> Bool {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            switch other._backing {
            case .immutable(let otherCs):
                return CFCharacterSetIsSupersetOfSet(cs, otherCs)
            case .mutable(let otherCs):
                return CFCharacterSetIsSupersetOfSet(cs, otherCs)
            case .swift(let otherCs):
                if let swiftCs = cs._backingSwiftCharacterSet {
                    return swiftCs.isSuperset(of: otherCs)
                } else {
                    let bitmap = CFCharacterSetCreateBitmapRepresentation(nil, cs) as Data
                    let swiftCs = _CharacterSet(bitmapRepresentation: bitmap)
                    return swiftCs.isSuperset(of: otherCs)
                }
            }
            
        case .mutable(let cs):
            switch other._backing {
            case .immutable(let otherCs):
                return CFCharacterSetIsSupersetOfSet(cs, otherCs)
            case .mutable(let otherCs):
                return CFCharacterSetIsSupersetOfSet(cs, otherCs)
            case .swift(let otherCs):
                if let swiftCs = cs._backingSwiftCharacterSet {
                    return swiftCs.isSuperset(of: otherCs)
                } else {
                    let bitmap = CFCharacterSetCreateBitmapRepresentation(nil, cs) as Data
                    let swiftCs = _CharacterSet(bitmapRepresentation: bitmap)
                    return swiftCs.isSuperset(of: otherCs)
                }
            }
        #endif
            
        case .swift(let cs):
            switch other._backing {
            #if FOUNDATION_FRAMEWORK
            case .immutable(let otherCs):
                if let swiftOtherCs = otherCs._backingSwiftCharacterSet {
                    return cs.isSuperset(of: swiftOtherCs)
                } else {
                    let bitmap = CFCharacterSetCreateBitmapRepresentation(nil, otherCs) as Data
                    let swiftOtherCs = _CharacterSet(bitmapRepresentation: bitmap)
                    return cs.isSuperset(of: swiftOtherCs)
                }
            case .mutable(let otherCs):
                if let swiftOtherCs = otherCs._backingSwiftCharacterSet {
                    return cs.isSuperset(of: swiftOtherCs)
                } else {
                    let bitmap = CFCharacterSetCreateBitmapRepresentation(nil, otherCs) as Data
                    let swiftOtherCs = _CharacterSet(bitmapRepresentation: bitmap)
                    return cs.isSuperset(of: swiftOtherCs)
                }
            #endif
            case .swift(let otherCs):
                return cs.isSuperset(of: otherCs)
            }
        }
    }
    
    // MARK: -
    
    var description: String {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return CFCopyDescription(cs) as String
        case .mutable(let cs):
            return CFCopyDescription(cs) as String
        #endif
        case .swift(let cs):
            return cs.description
        }
    }
    
    var debugDescription: String {
        switch _backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return CFCopyDescription(cs) as String
        case .mutable(let cs):
            return CFCopyDescription(cs) as String
        #endif
        case .swift(let cs):
            return cs.debugDescription
        }
    }
    
    // MARK: -
    
    #if FOUNDATION_FRAMEWORK
    public func bridgedReference() -> NSCharacterSet {
        switch _backing {
        case .immutable(let cs):
            return cs as NSCharacterSet
        case .mutable(let cs):
            return cs as NSCharacterSet
        case .swift(let cs):
            return _NSSwiftCharacterSet(characterSet: _CharacterSet(bitmapRepresentation: cs.bitmapRepresentation), isMutable: false) as NSCharacterSet
        }
    }
    #endif
}

#if FOUNDATION_FRAMEWORK
internal func foundation_swift_characterSet_enabled() -> Bool {
    return _foundation_swift_characterSet_enabled()
}
#else
internal func foundation_swift_characterSet_enabled() -> Bool { return true }
#endif

// MARK: -

/// A set of Unicode character values for use in search operations.
///
/// A `CharacterSet` represents a set of Unicode-compliant characters. Foundation types use `CharacterSet` to group characters together for searching operations, so that they can find any of a particular set of characters during a search.
///
/// This type provides "copy-on-write" behavior, and is also bridged to the Objective-C `NSCharacterSet` class.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct CharacterSet : Equatable, Hashable, SetAlgebra {
    
    fileprivate var _storage: __CharacterSetStorage
    
    // MARK: Init methods
    
    /// Initialize an empty instance.
    public init() {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            _storage = __CharacterSetStorage(mutableReference: CFCharacterSetCreateMutable(nil))
            return
        }
        #endif
        _storage = __CharacterSetStorage(swift: _CharacterSet())
    }
    
    /// Initialize with a range of integers.
    ///
    /// It is the caller's responsibility to ensure that the values represent valid `Unicode.Scalar` values, if that is what is desired.
    public init(charactersIn range: Range<Unicode.Scalar>) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            _storage = __CharacterSetStorage(immutableReference: CFCharacterSetCreateWithCharactersInRange(nil, _utfRangeToCFRange(range)))
            return
        }
        #endif
        _storage = __CharacterSetStorage(swift: _CharacterSet(charactersIn: range))
    }

    /// Initialize with a closed range of integers.
    ///
    /// It is the caller's responsibility to ensure that the values represent valid `Unicode.Scalar` values, if that is what is desired.
    public init(charactersIn range: ClosedRange<Unicode.Scalar>) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            _storage = __CharacterSetStorage(immutableReference: CFCharacterSetCreateWithCharactersInRange(nil, _utfRangeToCFRange(range)))
            return
        }
        #endif
        _storage = __CharacterSetStorage(swift: _CharacterSet(charactersIn: range))
    }

    /// Initialize with the characters in the given string.
    ///
    /// - parameter string: The string content to inspect for characters.
    public init(charactersIn string: __shared String) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            _storage = __CharacterSetStorage(immutableReference: CFCharacterSetCreateWithCharactersInString(nil, string as CFString))
            return
        }
        #endif
        _storage = __CharacterSetStorage(swift: _CharacterSet(charactersIn: string))
  }
    
    /// Initialize with a bitmap representation.
    ///
    /// This method is useful for creating a character set object with data from a file or other external data source.
    /// - parameter data: The bitmap representation.
    public init(bitmapRepresentation data: __shared Data) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            _storage = __CharacterSetStorage(immutableReference: CFCharacterSetCreateWithBitmapRepresentation(nil, data as CFData))
            return
        }
        #endif
        _storage = __CharacterSetStorage(swift: _CharacterSet(bitmapRepresentation: data))
    }
    
    /// Initialize with the contents of a file.
    ///
    /// Returns `nil` if there was an error reading the file.
    /// - parameter file: The file to read.
    public init?(contentsOfFile file: __shared String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: file, isDirectory: false)) else {
          return nil
        }
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            _storage = __CharacterSetStorage(immutableReference: CFCharacterSetCreateWithBitmapRepresentation(nil, data as CFData))
            return
        }
        #endif
        _storage = __CharacterSetStorage(swift: _CharacterSet(bitmapRepresentation: data))
    }

    #if FOUNDATION_FRAMEWORK
    private init(_bridged characterSet: __shared NSCharacterSet) {
        _storage = __CharacterSetStorage(immutableReference: characterSet.copy() as! CFCharacterSet)
    }
    #endif
    
    // Internal accessor for the underlying _CharacterSet - used by bridge classes
    internal var _characterSet: _CharacterSet {
        switch _storage._backing {
        case .swift(let cs):
            return cs
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cf):
            if let swiftCS = cf._backingSwiftCharacterSet {
                return swiftCS
            }
            return _CharacterSet(bitmapRepresentation: CFCharacterSetCreateBitmapRepresentation(nil, cf) as Data)
        case .mutable(let cf):
            if let swiftCS = cf._backingSwiftCharacterSet {
                return swiftCS
            }
            return _CharacterSet(bitmapRepresentation: CFCharacterSetCreateBitmapRepresentation(nil, cf) as Data)
        #endif
        }
    }
    
    internal init(_ characterSet: _CharacterSet) {
        _storage = __CharacterSetStorage(swift: characterSet)
    }
    
    #if FOUNDATION_FRAMEWORK
    private init(_uncopiedImmutableReference characterSet: CFCharacterSet) {
        _storage = __CharacterSetStorage(immutableReference: characterSet)
    }
    #endif

    fileprivate init(_uncopiedStorage: __CharacterSetStorage) {
        _storage = _uncopiedStorage
    }

    #if FOUNDATION_FRAMEWORK
    private init(_builtIn: __shared CFCharacterSetPredefinedSet) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            _storage = __CharacterSetStorage(immutableReference: CFCharacterSetGetPredefined(_builtIn))
            return
        }
        #endif
        _storage = __CharacterSetStorage(swift: _CharacterSet(_builtIn: _builtIn))
    }
    #endif
    
    // MARK: Static functions
    
    /// Returns a character set containing the characters in Unicode General Category Cc and Cf.
    public static var controlCharacters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .control)
        }
        #endif
        return _controlCharacters
    }
    
    /// Returns a character set containing the characters in Unicode General Category Zs and `CHARACTER TABULATION (U+0009)`.
    public static var whitespaces : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .whitespace)
        }
        #endif
        return _whitespaces
    }
    
    /// Returns a character set containing characters in Unicode General Category Z*, `U+000A ~ U+000D`, and `U+0085`.
    public static var whitespacesAndNewlines : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .whitespaceAndNewline)
        }
        #endif
        return _whitespacesAndNewlines
    }
    
    /// Returns a character set containing the characters in the category of Decimal Numbers.
    public static var decimalDigits : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .decimalDigit)
        }
        #endif
        return _decimalDigits
    }
    
    /// Returns a character set containing the characters in Unicode General Category L* & M*.
    public static var letters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .letter)
        }
        #endif
        return _letters
    }
    
    /// Returns a character set containing the characters in Unicode General Category Ll.
    public static var lowercaseLetters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .lowercaseLetter)
        }
        #endif
        return _lowercaseLetters
    }
    
    /// Returns a character set containing the characters in Unicode General Category Lu and Lt.
    public static var uppercaseLetters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .uppercaseLetter)
        }
        #endif
        return _uppercaseLetters
    }
    
    /// Returns a character set containing the characters in Unicode General Category M*.
    public static var nonBaseCharacters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .nonBase)
        }
        #endif
        return _nonBaseCharacters
    }
    
    /// Returns a character set containing the characters in Unicode General Categories L*, M*, and N*.
    public static var alphanumerics : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .alphaNumeric)
        }
        #endif
        return _alphanumerics
    }
    
    /// Returns a character set containing individual Unicode characters that can also be represented as composed character sequences (such as for letters with accents), by the definition of "standard decomposition" in version 3.2 of the Unicode character encoding standard.
    public static var decomposables : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .decomposable)
        }
        #endif
        return _decomposables
    }
    
    /// Returns a character set containing values in the category of Non-Characters or that have not yet been defined in version 3.2 of the Unicode standard.
    public static var illegalCharacters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .illegal)
        }
        #endif
        return _illegalCharacters
    }
    
    /// Returns a character set containing the characters in Unicode General Category P*.
    public static var punctuationCharacters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .punctuation)
        }
        #endif
        return _punctuationCharacters
    }
    
    /// Returns a character set containing the characters in Unicode General Category Lt.
    public static var capitalizedLetters : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .capitalizedLetter)
        }
        #endif
        return _capitalizedLetters
    }
    
    /// Returns a character set containing the characters in Unicode General Category S*.
    public static var symbols : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_builtIn: .symbol)
        }
        #endif
        return _symbols
    }
    
    /// Returns a character set containing the newline characters (`U+000A ~ U+000D`, `U+0085`, `U+2028`, and `U+2029`).
    public static var newlines : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        if foundation_swift_characterSet_enabled() {
            return _newlines
        } else {
            return CharacterSet(_builtIn: .newline)
        }
        #else
        return _newlines
        #endif
    }
    
    // MARK: Static functions, from NSURL

    /// Returns the character set for characters allowed in a user URL subcomponent.
    public static var urlUserAllowed : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: _CFURLComponentsGetURLUserAllowedCharacterSet() as NSCharacterSet))
        }
        #endif
        return _urlUserAllowed
    }
    
    /// Returns the character set for characters allowed in a password URL subcomponent.
    public static var urlPasswordAllowed : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: _CFURLComponentsGetURLPasswordAllowedCharacterSet() as NSCharacterSet))
        }
        #endif
        return _urlPasswordAllowed
    }
    
    /// Returns the character set for characters allowed in a host URL subcomponent.
    public static var urlHostAllowed : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: _CFURLComponentsGetURLHostAllowedCharacterSet() as NSCharacterSet))
        }
        #endif
        return _urlHostAllowed
    }
    
    /// Returns the character set for characters allowed in a path URL component.
    public static var urlPathAllowed : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: _CFURLComponentsGetURLPathAllowedCharacterSet() as NSCharacterSet))
        }
        #endif
        return _urlPathAllowed
    }
    
    /// Returns the character set for characters allowed in a query URL component.
    public static var urlQueryAllowed : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: _CFURLComponentsGetURLQueryAllowedCharacterSet() as NSCharacterSet))
        }
        #endif
        return _urlQueryAllowed
    }
    
    /// Returns the character set for characters allowed in a fragment URL component.
    public static var urlFragmentAllowed : CharacterSet {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_characterSet_enabled() else {
            return CharacterSet(_uncopiedStorage: __CharacterSetStorage(immutableReference: _CFURLComponentsGetURLFragmentAllowedCharacterSet() as NSCharacterSet))
        }
        #endif
        return _urlFragmentAllowed
    }
    
    // MARK: Immutable functions
    
    /// Returns a representation of the `CharacterSet` in binary format.
    @nonobjc
    public var bitmapRepresentation: Data {
        return _storage.bitmapRepresentation
    }
    
    /// Returns an inverted copy of the receiver.
    @nonobjc
    public var inverted : CharacterSet {
        return _storage.inverted
    }
    
    /// Returns true if the `CharacterSet` has a member in the specified plane.
    ///
    /// This method makes it easier to find the plane containing the members of the current character set. The Basic Multilingual Plane (BMP) is plane 0.
    public func hasMember(inPlane plane: UInt8) -> Bool {
        return _storage.hasMember(inPlane: plane)
    }
    
    // MARK: Mutable functions
    
    /// Insert a range of integer values in the `CharacterSet`.
    ///
    /// It is the caller's responsibility to ensure that the values represent valid `Unicode.Scalar` values, if that is what is desired.
    public mutating func insert(charactersIn range: Range<Unicode.Scalar>) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.insert(charactersIn: range)
    }

    /// Insert a closed range of integer values in the `CharacterSet`.
    ///
    /// It is the caller's responsibility to ensure that the values represent valid `Unicode.Scalar` values, if that is what is desired.
    public mutating func insert(charactersIn range: ClosedRange<Unicode.Scalar>) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.insert(charactersIn: range)
    }

    /// Remove a range of integer values from the `CharacterSet`.
    public mutating func remove(charactersIn range: Range<Unicode.Scalar>) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.remove(charactersIn: range)
    }

    /// Remove a closed range of integer values from the `CharacterSet`.
    public mutating func remove(charactersIn range: ClosedRange<Unicode.Scalar>) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.remove(charactersIn: range)
    }

    /// Insert the values from the specified string into the `CharacterSet`.
    public mutating func insert(charactersIn string: String) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.insert(charactersIn: string)
    }
    
    /// Remove the values from the specified string from the `CharacterSet`.
    public mutating func remove(charactersIn string: String) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.remove(charactersIn: string)
    }
    
    /// Invert the contents of the `CharacterSet`.
    public mutating func invert() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.invert()
    }
    
    // -----
    // MARK: -
    // MARK: SetAlgebra
    
    /// Insert a `Unicode.Scalar` representation of a character into the `CharacterSet`.
    ///
    /// `Unicode.Scalar` values are available on `Swift.String.UnicodeScalarView`.
    @discardableResult
    public mutating func insert(_ character: Unicode.Scalar) -> (inserted: Bool, memberAfterInsert: Unicode.Scalar) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        return _storage.insert(character)
    }

    /// Insert a `Unicode.Scalar` representation of a character into the `CharacterSet`.
    ///
    /// `Unicode.Scalar` values are available on `Swift.String.UnicodeScalarView`.
    @discardableResult
    public mutating func update(with character: Unicode.Scalar) -> Unicode.Scalar? {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        return _storage.update(with: character)
    }

    
    /// Remove a `Unicode.Scalar` representation of a character from the `CharacterSet`.
    ///
    /// `Unicode.Scalar` values are available on `Swift.String.UnicodeScalarView`.
    @discardableResult
    public mutating func remove(_ character: Unicode.Scalar) -> Unicode.Scalar? {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        return _storage.remove(character)
    }
    
    /// Test for membership of a particular `Unicode.Scalar` in the `CharacterSet`.
    public func contains(_ member: Unicode.Scalar) -> Bool {
        return _storage.contains(member)
    }
    
    /// Returns a union of the `CharacterSet` with another `CharacterSet`.
    public func union(_ other: CharacterSet) -> CharacterSet {
        return _storage.union(other._storage)
    }
    
    /// Sets the value to a union of the `CharacterSet` with another `CharacterSet`.
    public mutating func formUnion(_ other: CharacterSet) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.formUnion(other._storage)
    }
    
    /// Returns an intersection of the `CharacterSet` with another `CharacterSet`.
    public func intersection(_ other: CharacterSet) -> CharacterSet {
        return _storage.intersection(other._storage)
    }
    
    /// Sets the value to an intersection of the `CharacterSet` with another `CharacterSet`.
    public mutating func formIntersection(_ other: CharacterSet) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.formIntersection(other._storage)
    }

    /// Returns a `CharacterSet` created by removing elements in `other` from `self`.
    public func subtracting(_ other: CharacterSet) -> CharacterSet {
        return _storage.subtracting(other._storage)
    }

    /// Sets the value to a `CharacterSet` created by removing elements in `other` from `self`.
    public mutating func subtract(_ other: CharacterSet) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.subtract(other._storage)
    }

    /// Returns an exclusive or of the `CharacterSet` with another `CharacterSet`.
    public func symmetricDifference(_ other: CharacterSet) -> CharacterSet {
        return _storage.symmetricDifference(other._storage)
    }
    
    /// Sets the value to an exclusive or of the `CharacterSet` with another `CharacterSet`.
    public mutating func formSymmetricDifference(_ other: CharacterSet) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.mutableCopy()
        }
        _storage.formSymmetricDifference(other._storage)
    }
    
    /// Returns true if `self` is a superset of `other`.
    public func isSuperset(of other: CharacterSet) -> Bool {
        return _storage.isSuperset(of: other._storage)
    }

    // MARK: -
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage)
    }

    /// Returns true if the two `CharacterSet`s are equal.
    public static func ==(lhs : CharacterSet, rhs: CharacterSet) -> Bool {
        if lhs._storage === rhs._storage {
            return true
        }
        return lhs._storage == rhs._storage
    }
    
    #if FOUNDATION_FRAMEWORK
    // Can be used for fast access to the backing storage without bridging
    // The character set CANNOT be mutated from within this block or escape this block, even if it happens to be a CFMutableCharacterSet
    internal func withUnsafeImmutableStorage<R>(_ block: (CFCharacterSet) throws -> R) rethrows -> R {
        switch _storage._backing {
        case .immutable(let set):
            return try block(set)
        case .mutable(let set):
            return try block(set)
        case .swift(let set):
            // Create a temporary CFCharacterSet from the Swift character set's bitmap representation
            let bitmapData = set.bitmapRepresentation
            let cfSet = CFCharacterSetCreateWithBitmapRepresentation(nil, bitmapData as CFData)!
            return try block(cfSet)
        }
    }
    #endif
}


#if FOUNDATION_FRAMEWORK
// MARK: Objective-C Bridging
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension CharacterSet : ReferenceConvertible, _ObjectiveCBridgeable {
    public typealias ReferenceType = NSCharacterSet
    
    public static func _getObjectiveCType() -> Any.Type {
        return NSCharacterSet.self
    }
    
    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSCharacterSet {
        if (foundation_swift_characterSet_enabled()) {
            return _NSSwiftCharacterSet(characterSet: self._characterSet, isMutable: false)
        } else {
            return _storage.bridgedReference().copy() as! NSCharacterSet
        }
    }
    
    public static func _forceBridgeFromObjectiveC(_ input: NSCharacterSet, result: inout CharacterSet?) {
        if (foundation_swift_characterSet_enabled()) {
            if let input = input as? _NSSwiftCharacterSet {
                // Mutable bridges must be copied (caller could mutate after bridging);
                // immutable bridges can share storage.
                result = CharacterSet(input.isMutable ? input._characterSet.copy() : input._characterSet)
            } else if let input = input as? _NSSwiftImmortalCharacterSetBridge {
                result = CharacterSet(input._characterSet)
            } else {
                result = CharacterSet(_bridged: input)
            }
        } else {
            result = CharacterSet(_bridged: input)
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ input: NSCharacterSet, result: inout CharacterSet?) -> Bool {
        _forceBridgeFromObjectiveC(input, result: &result)
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSCharacterSet?) -> CharacterSet {
        guard let source else { return CharacterSet() }
        var result: CharacterSet?
        _forceBridgeFromObjectiveC(source, result: &result)
        return result!
    }
}
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension CharacterSet : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return _storage.description
    }

    public var debugDescription: String {
        return _storage.debugDescription
    }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSCharacterSet : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as CharacterSet)
    }
}
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension CharacterSet : Codable {
    private enum CodingKeys : Int, CodingKey {
        case bitmap
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bitmap = try container.decode(Data.self, forKey: .bitmap)
        self.init(bitmapRepresentation: bitmap)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.bitmapRepresentation, forKey: .bitmap)
    }
}

// CharacterSet is only Sendable in macOS 13.0+ (and aligned) releases because _bridgeToObjectiveC() previously returned the internal reference pointer instead of a copy of the reference
// This could inadvertently vend a pointer to the internal mutable state held by the value type, breaking Sendable safety
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension CharacterSet : Sendable {}

// MARK: - Singletons

extension CharacterSet {
    static let _controlCharacters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .control)))
    }()
    
    static let _whitespaces: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .whitespace)))
    }()
    
    static let _whitespacesAndNewlines: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .whitespaceAndNewline)))
    }()
    
    static let _decimalDigits: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .decimalDigit)))
    }()
    
    static let _letters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .letter)))
    }()
    
    static let _lowercaseLetters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .lowercaseLetter)))
    }()
    
    static let _uppercaseLetters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .uppercaseLetter)))
    }()
    
    static let _nonBaseCharacters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .nonBase)))
    }()
    
    static let _alphanumerics: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .alphanumeric)))
    }()
    
    static let _decomposables: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .canonicalDecomposable)))
    }()
    
    static let _illegalCharacters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .illegal)))
    }()
    
    static let _punctuationCharacters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .punctuation)))
    }()
    
    static let _capitalizedLetters: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .titlecase)))
    }()
    
    static let _symbols: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .symbolAndOperator)))
    }()
    
    static let _newlines: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(builtInType: .newline)))
    }()

    static let _urlFragmentAllowed: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(charactersIn: "!$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~")))
    }()
    
    static let _urlHostAllowed: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(charactersIn: "!$&'()*+,-.0123456789:;=ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_abcdefghijklmnopqrstuvwxyz~")))
    }()
    
    static let _urlPasswordAllowed: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(charactersIn: "!$&'()*+,-.0123456789;=ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~")))
    }()
    
    static let _urlPathAllowed: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(charactersIn: "!$&'()*+,-./0123456789:;=@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~")))
    }()
    
    static let _urlQueryAllowed: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(charactersIn: "!$&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~")))
    }()
    
    static let _urlUserAllowed: CharacterSet = {
        return CharacterSet(_uncopiedStorage: __CharacterSetStorage(swift: _CharacterSet(charactersIn: "!$&'()*+,-.0123456789;=ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~")))
    }()
}

extension CharacterSet {
    // Internal for comparing pointer equality to URL component allowed sets
    func hasIdenticalSwiftStorage(to other: CharacterSet) -> Bool {
        switch (self._storage._backing, other._storage._backing) {
        case (.swift(let a), .swift(let b)):
            return a === b
        #if FOUNDATION_FRAMEWORK
        default:
            return false
        #endif
        }
    }

    // Returns a UInt128 where bit i is 1 if ASCII value i is allowed in the set
    var asciiAllowedMask: UInt128 {
        switch _storage._backing {
        #if FOUNDATION_FRAMEWORK
        case .immutable(let cs):
            return _CharacterSet._asciiMask(fromBitmap: (CFCharacterSetCreateBitmapRepresentation(nil, cs) as Data).span)
        case .mutable(let cs):
            return _CharacterSet._asciiMask(fromBitmap: (CFCharacterSetCreateBitmapRepresentation(nil, cs) as Data).span)
        #endif
        case .swift(let cs):
            return cs.asciiAllowedMask
        }
    }
}

#if FOUNDATION_FRAMEWORK
extension CFCharacterSet {
    var _backingSwiftCharacterSet: _CharacterSet? {
        let ns = self as NSCharacterSet
        return (ns as? _NSSwiftCharacterSet)?._characterSet ?? (ns as? _NSSwiftImmortalCharacterSetBridge)?._characterSet
    }
}
#endif
