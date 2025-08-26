//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import Foundation_Private
#endif

extension Locale {

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Language : Hashable, Codable, Sendable {

        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        /// Represents a language identifier
        public struct Components : Hashable, Codable, Sendable {
            public var languageCode: Locale.LanguageCode?
            public var script: Locale.Script?
            public var region: Locale.Region?

            public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, region: Locale.Region? = nil) {
                self.languageCode = languageCode
                self.script = script
                self.region = region
            }

            package var identifier: String {
                var result: String = ""

                if let languageCode = languageCode {
                    result += languageCode._normalizedIdentifier
                }
                if let script = script, !script.identifier.isEmpty {
                    result += "-"
                    result += script._normalizedIdentifier
                }
                if let region = region, !region.identifier.isEmpty {
                    result += "_"
                    result += region._normalizedIdentifier
                }

                return result
            }
            
#if !FOUNDATION_FRAMEWORK
            @_spi(SwiftCorelibsFoundation) public var _identifier: String { identifier }
#endif
        }

        package var components: Language.Components
        
#if !FOUNDATION_FRAMEWORK
        @_spi(SwiftCorelibsFoundation) public var _components: Language.Components {
            components
        }
#endif
        
        public init(components: Language.Components) {
            self.components = components
        }

        public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, region: Locale.Region? = nil) {
            self.components = Components(languageCode: languageCode, script: script, region: region)
        }

        /// Returns a list of system languages, includes the languages of all product localization for the current platform
        public static var systemLanguages: [Language] {
#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
            NSLocale.systemLanguages().map {
                let comp = Components(identifier: $0 as! String)
                return Language(components: comp)
            }
#else
            // TODO: Read language list for other platforms
            return []
#endif
        }
    }
}
