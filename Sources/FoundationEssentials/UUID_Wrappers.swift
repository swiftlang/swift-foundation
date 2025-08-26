//===----------------------------------------------------------------------===//
 //
 // This source file is part of the Swift.org open source project
 //
 // Copyright (c) 2022 Apple Inc. and the Swift project authors
 // Licensed under Apache License v2.0 with Runtime Library Exception
 //
 // See https://swift.org/LICENSE.txt for license information
 //
 //===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

internal import _ForSwiftFoundation

#if canImport(Darwin.uuid)
// Needed this for backward compatibility even though we don't use it.
import Darwin.uuid
#endif

@available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *)
extension UUID : ReferenceConvertible {
     public typealias ReferenceType = NSUUID

     @_semantics("convertToObjectiveC")
     public func _bridgeToObjectiveC() -> NSUUID {
         return __NSConcreteUUID(value: self)
     }

     public static func _forceBridgeFromObjectiveC(_ x: NSUUID, result: inout UUID?) {
         if !_conditionallyBridgeFromObjectiveC(x, result: &result) {
             fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
         }
     }

     public static func _conditionallyBridgeFromObjectiveC(_ input: NSUUID, result: inout UUID?) -> Bool {
         // Is this NSUUID already backed by a UUID?
         guard let swiftInput = input as? __NSConcreteUUID else {
             // Fallback to using bytes
             var bytes = uuid_t(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
             input.getBytes(&bytes)
             result = UUID(uuid: bytes)
             return true
         }
         
         result = swiftInput._storage
         return true
     }

     @_effects(readonly)
     public static func _unconditionallyBridgeFromObjectiveC(_ source: NSUUID?) -> UUID {
         var result: UUID?
         _forceBridgeFromObjectiveC(source!, result: &result)
         return result!
     }
 }

@available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *)
extension NSUUID : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as UUID)
    }
}

@objc(__NSConcreteUUID)
internal class __NSConcreteUUID : _NSUUIDBridge, @unchecked Sendable {
    final var _storage: UUID

    fileprivate init(value: Foundation.UUID) {
        _storage = value
        super.init()
    }

    override public init() {
        _storage = Foundation.UUID()
        super.init()
    }
    
    override static var supportsSecureCoding: Bool { true }
    
    required init?(coder: NSCoder) {
        guard coder.allowsKeyedCoding else {
            coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Cannot be decoded without keyed coding"]))
            return nil
        }

        var decodedByteLength = 0
        let bytes = coder.decodeBytes(forKey: "NS.uuidbytes", returnedLength: &decodedByteLength)
        
        guard let bytes else {
            if NSUUID._compatibilityBehavior {
                let empty = uuid_t(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
                _storage = Foundation.UUID(uuid: empty)
                super.init()
                return
            } else {
                coder.failWithError(CocoaError(CocoaError.coderValueNotFound, userInfo: [NSDebugDescriptionErrorKey : "UUID bytes not found in archive"]))
                return nil
            }
        }
        
        guard decodedByteLength == MemoryLayout<uuid_t>.size else {
            if NSUUID._compatibilityBehavior {
                let empty = uuid_t(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
                _storage = Foundation.UUID(uuid: empty)
                super.init()
                return
            } else {
                coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "UUID bytes were not the expected length"]))
                return nil
            }
        }
        
        let cUUID = bytes.withMemoryRebound(to: uuid_t.self, capacity: 1, { $0.pointee })
        _storage = Foundation.UUID(uuid: cUUID)
        super.init()
    }

    override func encode(with coder: NSCoder) {
        _storage.withUUIDBytes { buffer in
            coder.encodeBytes(buffer.baseAddress, length: buffer.count, forKey: "NS.uuidbytes")
        }
    }
    
    override public init?(uuidString: String) {
        guard let swiftUUID = Foundation.UUID(uuidString: uuidString) else {
            if NSUUID._compatibilityBehavior {
                let empty = uuid_t(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
                _storage = Foundation.UUID(uuid: empty)
                super.init()
                return
            } else {
                return nil
            }
        }
        _storage = swiftUUID
        super.init()
    }

    override public init(uuidBytes: UnsafePointer<UInt8>?) {
        let cUUID = uuidBytes?.withMemoryRebound(to: uuid_t.self, capacity: 1, {
            $0.pointee
        }) ?? (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        _storage = Foundation.UUID(uuid: cUUID)
        super.init()
    }

    override open func getBytes(_ bytes: UnsafeMutablePointer<UInt8>) {
        _storage.withUUIDBytes { buffer in
            bytes.initialize(from: buffer.baseAddress!, count: buffer.count)
        }
    }

    override open var uuidString: String {
        @objc(UUIDString) get {
            _storage.uuidString
        }
    }
    
    override var description: String {
        self.uuidString
    }
    
    override var debugDescription: String {
        withUnsafePointer(to: self) { ptr in
            "<\(Self.self) \(ptr.debugDescription)> \(self.uuidString)"
        }
    }
    
    override var classForCoder: AnyClass {
        return NSUUID.self
    }
}

#endif

