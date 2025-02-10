//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

@_exported import Foundation // Clang module
@_spi(Foundation) import Swift
internal import CoreFoundation_Private.CFString
internal import ObjectiveC_Private.objc_internal
internal import CoreFoundation_Private.ForFoundationOnly

//===----------------------------------------------------------------------===//
// New Strings
//===----------------------------------------------------------------------===//

//
// Conversion from NSString to Swift's native representation
//

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String {
    public init(_ cocoaString: NSString) {
        self = String._unconditionallyBridgeFromObjectiveC(cocoaString)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String : _ObjectiveCBridgeable {
    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSString {
        // This method should not do anything extra except calling into the
        // implementation inside core.  (These two entry points should be
        // equivalent.)
        return unsafeBitCast(_bridgeToObjectiveCImpl(), to: NSString.self)
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSString, result: inout String?) {
        result = String._unconditionallyBridgeFromObjectiveC(x)
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSString, result: inout String?) -> Bool {
        self._forceBridgeFromObjectiveC(x, result: &result)
        return result != nil
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSString?) -> String {
        // `nil` has historically been used as a stand-in for an empty
        // string; map it to an empty string.
        guard let source = source else {
            return ""
        }
        
#if !(arch(i386) || arch(arm) || arch(arm64_32))
        var SMALL_STRING_CAPACITY:Int { 15 }

        if OBJC_HAVE_TAGGED_POINTERS == 1 && _objc_isTaggedPointer(unsafeBitCast(source, to: UnsafeRawPointer.self)) {
            let tag = _objc_getTaggedPointerTag(unsafeBitCast(source, to: UnsafeRawPointer.self))
            if tag == OBJC_TAG_NSString {
                return String(unsafeUninitializedCapacity: SMALL_STRING_CAPACITY) {
                    _NSTaggedPointerStringGetBytes(source, $0.baseAddress!)
                }
            } else if tag.rawValue == 22 /* OBJC_TAG_Foundation_1 */ {
                let cStr = source.utf8String!
                return String.init(utf8String: cStr)!
            }
        }
#endif
        
        var ascii = false
        var len = 0
        var mutable = false
        var constant = false
        
        if __CFStringIsCF(unsafeBitCast(source, to: CFString.self), &mutable, &len, &ascii, &constant) {
            if len == 0 {
                return ""
            }

            if constant {
                if ascii {
                    return String(_immortalCocoaString: source, count: len, encoding: Unicode.ASCII.self)
                } else {
                    return String(_immortalCocoaString: source, count: len, encoding: Unicode.UTF16.self)
                }
            }
            
            /*
             If `source` is a mutable string, we should eagerly bridge.
             Lazy bridging will still wastefully copy it to immutable first.
             */
            if mutable {
                let eagerBridge = { (source: NSString, encoding: CFStringBuiltInEncodings, capacity: Int) -> String? in
                    let result = String(unsafeUninitializedCapacity: capacity) { buffer in
                        var usedLen = 0
                        let convertedCount = _CFNonObjCStringGetBytes(
                            unsafeBitCast(source, to: CFString.self),
                            CFRangeMake(0, len),
                            encoding.rawValue,
                            0,
                            false,
                            buffer.baseAddress.unsafelyUnwrapped,
                            capacity,
                            &usedLen
                        )
                        if convertedCount != len {
                            return 0
                        }
                        return usedLen
                    }
                    return result.isEmpty ? nil : result
                }
                if ascii {
                    if let result = eagerBridge(source, CFStringBuiltInEncodings.ASCII, len) {
                        return result
                    }
                } else {
                    if let result = eagerBridge(source, CFStringBuiltInEncodings.UTF8, source.lengthOfBytes(using: String.Encoding.utf8.rawValue)) {
                        return result
                    }
                }
            }
        } else { //not an __NSCFString
            // If `source` is a Swift-native string ("rebridging"), we should return it as-is.
            if let result = String(_nativeStorage: source) {
                return result
            }
            
            len = source.length
            if len == 0 {
                return ""
            }
        }

        /*
         Future
         • If `source` is an immutable NSCFString, we should get what String
            needs with as few calls as possible. A unified
            "get isASCII, providesFastUTF8, length" method? Is this the same
            "prepare for bridging" concept?
         • Complication: if we can prove an NSCFString has no associated objects
            we may want to eagerly bridge it. Checking that is rdar://50255938,
            but even once we have that, when to eagerly bridge vs lazily bridge
            is not necessarily an obvious set of tradeoffs.
         
         Existing stdlib entry points:
         `String(unsafeUninitializedCapacity:, initializingWith:)`
         `String(_cocoaString:)`
         `String?(_nativeStorage:)`
         `String(_immortalCocoaString:, count:, encoding:)`
         
         Should the stdlib expose
         `String(_preparedCocoaString:,isASCII:,providesFastUTF8:,length:)` for
         this code to use? Is there a better signature? (This one is just the
         one from the underlying _StringGuts() initializer)
         
         If we do all this, aside from major speedups, we can delete everything
         in _bridgeCocoaString() in the stdlib, keeping all the smarts about
         how bridging works in one place (here).
         */
        
        return String(_cocoaString: source)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Substring : _ObjectiveCBridgeable {
    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSString {
        return String(self)._bridgeToObjectiveC()
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSString, result: inout Substring?) {
        let s = String(x)
        result = s[...]
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSString, result: inout Substring?) -> Bool {
        self._forceBridgeFromObjectiveC(x, result: &result)
        return result != nil
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSString?) -> Substring {
        let str = String._unconditionallyBridgeFromObjectiveC(source)
        return str[...]
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String: CVarArg {}

/*
 This is on NSObject so that the stdlib can call it in StringBridge.swift
 without having to synthesize a receiver (e.g. lookup a class or allocate)
 
 TODO: In the future (once the Foundation overlay can know about SmallString),
 we should move the caller of this method up into the overlay and avoid this
 indirection.
 */
private extension NSObject {
    // The ObjC selector has to start with "new" to get ARC to not autorelease
    @_effects(releasenone)
    @objc(newTaggedNSStringWithASCIIBytes_:length_:)
    func createTaggedString(bytes: UnsafePointer<UInt8>,
                            count: Int) -> AnyObject? {
        if let result = _CFStringCreateTaggedPointerString(
            bytes,
            count
        ) {
            return result.takeRetainedValue() as NSString as NSString? //just "as AnyObject" inserts unwanted bridging
        }
        return nil
    }
}

extension Substring {
    func _components(separatedBy characterSet: CharacterSet) -> [String] {
        var result = [String]()
        var searchStart = startIndex
        while searchStart < endIndex {
            let r = self[searchStart...]._rangeOfCharacter(from: characterSet, options: [])
            guard let r, !r.isEmpty else {
                break
            }

            result.append(String(self[searchStart ..< r.lowerBound]))
            searchStart = r.upperBound
        }

        result.append(String(self[searchStart..<endIndex]))

        return result
    }
}

extension BidirectionalCollection where Element == Unicode.Scalar, Index == String.Index {
    func _trimmingCharacters(in set: CharacterSet) -> SubSequence {

        var idx = startIndex
        while idx < endIndex && set.contains(self[idx]) {
            formIndex(after: &idx)
        }

        let startOfNonTrimmedRange = idx // Points at the first char not in the set
        guard startOfNonTrimmedRange != endIndex else {
            return self[endIndex...]
        }

        let beforeEnd = index(before: endIndex)
        guard startOfNonTrimmedRange < beforeEnd else {
            return self[startOfNonTrimmedRange ..< endIndex]
        }

        var backIdx = beforeEnd
        // No need to bound-check because we've already trimmed from the beginning, so we'd definitely break off of this loop before `backIdx` rewinds before `startIndex`
        while set.contains(self[backIdx]) {
            formIndex(before: &backIdx)
        }
        return self[startOfNonTrimmedRange ... backIdx]
    }

}

// START: Workaround for https://github.com/swiftlang/swift/pull/78697

// The extensions below are temporarily relocated to work around a compiler crash.
// Once that crash is resolved, they should be moved back to their original files.

#if !NO_FILESYSTEM

// Relocated from FileManager+Utilities.swift
#if FOUNDATION_FRAMEWORK && os(macOS)
extension URLResourceKey {
    static var _finderInfoKey: Self { URLResourceKey("_NSURLFinderInfoKey") }
}
#endif

// Relocated from FileManager+Files.swift
#if FOUNDATION_FRAMEWORK
internal import DarwinPrivate.sys.content_protection
#endif

#if !os(Windows)
#if FOUNDATION_FRAMEWORK
extension FileProtectionType {
    var intValue: Int32? {
        switch self {
        case .complete: PROTECTION_CLASS_A
        case .init(rawValue: "NSFileProtectionWriteOnly"), .completeUnlessOpen: PROTECTION_CLASS_B
        case .init(rawValue: "NSFileProtectionCompleteUntilUserAuthentication"), .completeUntilFirstUserAuthentication: PROTECTION_CLASS_C
        case .none: PROTECTION_CLASS_D
        #if !os(macOS)
        case .completeWhenUserInactive: PROTECTION_CLASS_CX
        #endif
        default: nil
        }
    }
    
    init?(intValue value: Int32) {
        switch value {
        case PROTECTION_CLASS_A: self = .complete
        case PROTECTION_CLASS_B: self = .completeUnlessOpen
        case PROTECTION_CLASS_C: self = .completeUntilFirstUserAuthentication
        case PROTECTION_CLASS_D: self = .none
        #if !os(macOS)
        case PROTECTION_CLASS_CX: self = .completeWhenUserInactive
        #endif
        default: return nil
        }
    }
}
#endif
#endif
#endif

#endif

#if !NO_FILESYSTEM
// Relocated from FileManager+Files.swift. Originally fileprivate.
extension FileAttributeKey {
    internal static var _extendedAttributes: Self { Self("NSFileExtendedAttributes") }
}
#endif

// END: Workaround for https://github.com/swiftlang/swift/pull/78697
