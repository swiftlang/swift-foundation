//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

package struct StringsDictConfig {
    package struct InnerFormatInfo {
        let innerFormat: String?
        let innerKind: ParsedFormatSpec.Kind?
    }

    private enum Storage {
        case swift([String : Any])
        #if FOUNDATION_FRAMEWORK
        case objc(NSDictionary)
        #endif
    }

    package struct RuleConfig {
        private let _storage: Storage

        package init(_ dictionary: [String : Any]) {
            _storage = .swift(dictionary)
        }

        #if FOUNDATION_FRAMEWORK
        init(_ ns: NSDictionary) {
            _storage = .objc(ns)
        }
        #endif

        package subscript(key: String) -> Any? {
            switch _storage {
            case .swift(let dictionary):
                dictionary[key]
            #if FOUNDATION_FRAMEWORK
            case .objc(let nsDictionary):
                nsDictionary.object(forKey: key)
            #endif
            }
        }

        #if FOUNDATION_FRAMEWORK
        subscript(key: CFString) -> Any? {
            switch _storage {
            case .swift(let dictionary):
                dictionary[key as String]
            case .objc(let nsDictionary):
                nsDictionary.object(forKey: key)
            }
        }
        #endif
    }

    private let _storage: Storage

    package init(_ dictionary: [String : Any]) {
        _storage = .swift(dictionary)
    }

    #if FOUNDATION_FRAMEWORK
    init(_ ns: NSDictionary) {
        _storage = .objc(ns)
    }
    #endif

    package subscript(configKey: String) -> RuleConfig? {
        switch _storage {
        case .swift(let dictionary):
            dictionary[configKey].map {
                RuleConfig($0 as! [String : Any])
            }
        #if FOUNDATION_FRAMEWORK
        case .objc(let nsDictionary):
            nsDictionary.object(forKey: configKey).map {
                RuleConfig($0 as! NSDictionary)
            }
        #endif
        }
    }
}

extension ParsedFormatSpec {
    #if FOUNDATION_FRAMEWORK || hasFeature(Embedded)
    func innerFormatInfo(in format: StringContents, from config: StringsDictConfig?) throws(CocoaError) -> StringsDictConfig.InnerFormatInfo? {
        try innerFormatInfo_localized(in: format, from: config)
    }
    #else
    package dynamic func innerFormatInfo(in format: StringContents, from config: StringsDictConfig?) throws(CocoaError) -> StringsDictConfig.InnerFormatInfo? {
        nil
    }
    #endif

    func resolvedKindAndStringsDictInfo(in format: StringContents, with config: StringsDictConfig?) throws(CocoaError) -> (kind: Kind?, info: StringsDictConfig.InnerFormatInfo?) {
        if let innerInfo = try innerFormatInfo(in: format, from: config) {
            // Even if the innerKind is nil, we return it here because a nil innerKind means it uses no argument (i.e. a pluralizationNumber)
            return (innerInfo.innerKind, innerInfo)
        } else {
            return (self.kind, nil)
        }
    }

    func kindAccountingForStringsDict(in format: StringContents, with config: StringsDictConfig?) throws(CocoaError) -> Kind?  {
        try resolvedKindAndStringsDictInfo(in: format, with: config).kind
    }
}
