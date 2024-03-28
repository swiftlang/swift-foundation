//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// Developers can also add the attributes to pre-defined scopes of attributes, which are used to provide type information to the encoding and decoding of AttributedString values, as well as allow for dynamic member lookup in Runs of AttributedStrings.
// Example, where ForegroundColor is an existing AttributedStringKey:
// struct MyAttributes : AttributeScope {
//     var foregroundColor : ForegroundColor
// }
// An AttributeScope can contain other scopes as well.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributeScope : DecodingConfigurationProviding, EncodingConfigurationProviding {
    static var decodingConfiguration: AttributeScopeCodableConfiguration { get }
    static var encodingConfiguration: AttributeScopeCodableConfiguration { get }
}

@_nonSendable
@frozen
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum AttributeScopes { }

#if FOUNDATION_FRAMEWORK

import Darwin
internal import MachO.dyld
@preconcurrency internal import ReflectionInternal

fileprivate struct ScopeDescription : Sendable {
    var attributes: [String : any AttributedStringKey.Type] = [:]
    var markdownAttributes: [String : any MarkdownDecodableAttributedStringKey.Type] = [:]
    
    mutating func merge(_ other: Self) {
        attributes.merge(other.attributes, uniquingKeysWith: { current, new in new })
        markdownAttributes.merge(other.markdownAttributes, uniquingKeysWith: { current, new in new })
    }
}

fileprivate struct LoadedScopeCache : Sendable {
    private enum ScopeType : Equatable {
        case loaded(any AttributeScope.Type)
        case notLoaded
        
        static func == (lhs: LoadedScopeCache.ScopeType, rhs: LoadedScopeCache.ScopeType) -> Bool {
            switch (lhs, rhs) {
            case (.notLoaded, .notLoaded): true
            case (.loaded(let a), .loaded(let b)): a == b
            default: false
            }
        }
    }
    private var scopeMangledNames : [String : ScopeType]
    private var lastImageCount: UInt32
    private var scopeContents : [Type : ScopeDescription]
    
    init() {
        scopeMangledNames = [:]
        scopeContents = [:]
        lastImageCount = 0
    }
    
    mutating func scopeType(
        for name: String,
        in path: String
    ) -> (any AttributeScope.Type)? {
        if let cached = scopeMangledNames[name] {
            if case .loaded(let foundScope) = cached {
                // We have a cached result, provide it to the caller
                return foundScope
            }
            let currentImageCount = _dyld_image_count()
            if lastImageCount == currentImageCount {
                // We didn't find the scope last time we checked and no new images have been loaded
                return nil
            }
            // We didn't find the scope last time but new images have been loaded so remove all lookup misses from the cache
            lastImageCount = currentImageCount
            scopeMangledNames = scopeMangledNames.filter {
                $0.value != .notLoaded
            }
        }
        
        guard let handle = dlopen(path, RTLD_NOLOAD),
             let symbol = dlsym(handle, name) else {
            scopeMangledNames[name] = .notLoaded
            return nil
        }
        
        guard let type = unsafeBitCast(symbol, to: Any.Type.self) as? any AttributeScope.Type else {
            fatalError("Symbol \(name) is not an AttributeScope type")
        }
        scopeMangledNames[name] = .loaded(type)
        return type
    }
    
    subscript(_ type: any AttributeScope.Type) -> ScopeDescription? {
        get {
            scopeContents[Type(type)]
        }
        set {
            scopeContents[Type(type)] = newValue
        }
    }
}

fileprivate let _loadedScopeCache = LockedState(initialState: LoadedScopeCache())

internal func _loadDefaultAttributes() -> [String : any AttributedStringKey.Type] {
    // On native macOS, the UI framework that gets loaded is AppKit. On
    // macCatalyst however, we load a version of UIKit.
    #if !targetEnvironment(macCatalyst)
    // AppKit
    let macUIScope = (
        "$s10Foundation15AttributeScopesO6AppKitE0dE10AttributesVN",
        "/System/Library/Frameworks/AppKit.framework/AppKit"
    )
    #else
    // UIKit on macOS
    let macUIScope = (
        "$s10Foundation15AttributeScopesO5UIKitE0D10AttributesVN",
        "/System/iOSSupport/System/Library/Frameworks/UIKit.framework/UIKit"
    )
    #endif

    // Gather the metatypes for all scopes currently loaded into the process (may change over time)
    let defaultScopes = _loadedScopeCache.withLock { cache in
        [
            macUIScope,
            // UIKit
            (
                "$s10Foundation15AttributeScopesO5UIKitE0D10AttributesVN",
                "/System/Library/Frameworks/UIKit.framework/UIKit"
            ),
            // SwiftUI
            (
                "$s10Foundation15AttributeScopesO7SwiftUIE0D12UIAttributesVN",
                "/System/Library/Frameworks/SwiftUI.framework/SwiftUI"
            ),
            // Accessibility
            (
                "$s10Foundation15AttributeScopesO13AccessibilityE0D10AttributesVN",
                "/System/Library/Frameworks/Accessibility.framework/Accessibility"
            )
        ].compactMap {
            cache.scopeType(for: $0.0, in: $0.1)
        }
    }
    
    // Walk each scope (checking the cache) and gather each scope's attribute table
    let defaultAttributeTypes = (defaultScopes + [AttributeScopes.FoundationAttributes.self]).map {
        $0.attributeKeyTypes()
    }

    // Merge the attribute tables together into one large table
    return defaultAttributeTypes.reduce([:]) { result, item in
        result.merging(item) { current, new in new }
    }
}

// TODO: Support AttributeScope key finding in FoundationPreview
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
internal extension AttributeScope {
    private static var scopeDescription: ScopeDescription {
        if let cached = _loadedScopeCache.withLock({ $0[Self.self] }) {
            return cached
        }
        
        var desc = ScopeDescription()
        for field in Type(Self.self).fields {
            switch field.type.swiftType {
            case let attribute as any AttributedStringKey.Type:
                desc.attributes[attribute.name] = attribute
                if let markdownAttribute = attribute as? any MarkdownDecodableAttributedStringKey.Type {
                    desc.markdownAttributes[markdownAttribute.markdownName] = markdownAttribute
                }
            case let scope as any AttributeScope.Type:
                desc.merge(scope.scopeDescription)
            default: break
            }
        }
        let _desc = desc
        _loadedScopeCache.withLock {
            $0[Self.self] = _desc
        }
        return desc
    }
    
    static func attributeKeyTypes() -> [String : any AttributedStringKey.Type] {
        Self.scopeDescription.attributes
    }
    
    static func markdownKeyTypes() -> [String : any MarkdownDecodableAttributedStringKey.Type] {
        Self.scopeDescription.markdownAttributes
    }
}

#endif // FOUNDATION_FRAMEWORK
