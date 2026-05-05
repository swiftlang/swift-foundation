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

    /// A type that represents a language, as used in a locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Language : Hashable, Codable, Sendable {

        /// A type that identifies a language by its various components.
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public struct Components : Hashable, Codable, Sendable {
            /// The language code that identifies this language.
            public var languageCode: Locale.LanguageCode?
            /// The written script used by this language.
            public var script: Locale.Script?
            /// The region used with this language.
            public var region: Locale.Region?

            /// Creates a language components instance from a given language code, script, and region.
            ///
            /// - Parameters:
            ///   - languageCode: The language code to use for the new components instance.
            ///   - script: The script to use for the new components instance.
            ///   - region: The region to use for the new components instance.
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
        
        /// Creates a language from its component values.
        ///
        /// - Parameter components: A `Language.Components` instance that provides a custom language code, region, and script for the new `Language` instance.
        public init(components: Language.Components) {
            self.components = components
        }

        /// Creates a language from a given language code, script, and region.
        ///
        /// - Parameters:
        ///   - languageCode: A language code, typically created from a two- or three-letter language code specified by ISO 639.
        ///   - script: The script to use for the new locale components instance.
        ///   - region: The region to use for the new components instance.
        public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, region: Locale.Region? = nil) {
            self.components = Components(languageCode: languageCode, script: script, region: region)
        }

        /// An array of the system's supported languages.
        ///
        /// The returned array includes the languages of all product localizations for the current platform.
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
