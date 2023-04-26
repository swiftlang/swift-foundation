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

@_implementationOnly import FoundationICU

extension Locale {

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Language : Hashable, Codable, Sendable {

        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        /// Represents a language identifier
        public struct Components : Hashable, Codable, Sendable {
            public var languageCode: Locale.LanguageCode?
            public var script: Locale.Script?
            public var region: Locale.Region?

            /// - Parameter identifier: Unicode language identifier, such as "en-US", "es-419", "zh-Hant-TW"
            public init(identifier: String) {
                let languageCode = _withFixedCharBuffer { buffer, size, status in
                    uloc_getLanguage(identifier, buffer, size, &status)
                }
                let scriptCode = _withFixedCharBuffer { buffer, size, status in
                    uloc_getScript(identifier, buffer, size, &status)
                }
                let countryCode = _withFixedCharBuffer { buffer, size, status in
                    uloc_getCountry(identifier, buffer, size, &status)
                }

                if let languageCode {
                    self.languageCode = LanguageCode(languageCode)
                }
                if let scriptCode {
                    self.script = Script(scriptCode)
                }
                if let countryCode {
                    self.region = Region(countryCode)
                }
            }

            public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, region: Locale.Region? = nil) {
                self.languageCode = languageCode
                self.script = script
                self.region = region
            }

            public init(language: Locale.Language) {
                self.languageCode = language.languageCode
                self.script = language.script
                self.region = language.region
            }

            internal var identifier: String {
                var result: String = ""

                if let languageCode = languageCode {
                    result += languageCode._normalizedIdentifier
                }
                if let script = script {
                    result += "-"
                    result += script._normalizedIdentifier
                }
                if let region = region {
                    result += "_"
                    result += region._normalizedIdentifier
                }

                return result
            }
        }

        var components: Language.Components
        public init(components: Language.Components) {
            self.components = components
        }

        public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, region: Locale.Region? = nil) {
            self.components = Components(languageCode: languageCode, script: script, region: region)
        }

        /// Creates a `Language` with the language identifier
        /// - Parameter identifier: Unicode language identifier, such as "en-US", "es-419", "zh-Hant-TW"
        public init(identifier: String) {
            self.components = Components(identifier: identifier)
        }

        /// Ordering of lines within a page.
        /// For example, top-to-bottom for English; right-to-left for Mongolian in the Mongolian Script
        /// - note: See also `characterDirection`.
        public var lineLayoutDirection: Locale.LanguageDirection {
            var status = U_ZERO_ERROR
            let orientation = uloc_getLineOrientation(components.identifier, &status)
            guard status.isSuccess else {
                return .unknown
            }

            return LanguageDirection(layoutType: orientation)
        }

        /// Ordering of characters within a line.
        /// For example, left-to-right for English; top-to-bottom for Mongolian in the Mongolian Script
        public var characterDirection: Locale.LanguageDirection {
            var status = U_ZERO_ERROR
            let orientation = uloc_getCharacterOrientation(components.identifier, &status)
            guard status.isSuccess else {
                return .unknown
            }

            return LanguageDirection(layoutType: orientation)
        }

        // MARK: - Getting information

        /// Returns the parent language of a language. For example, the parent language of `"en_US_POSIX"` is `"en_US"`
        /// Returns nil if the parent language cannot be determined
        public var parent: Language? {
            let parentID = _withFixedCharBuffer { buffer, size, status in
                return ualoc_getAppleParent(components.identifier, buffer, size, &status)
            }

            if let parentID {
                let comp = Language.Components(identifier: parentID)
                return Language(components: comp)
            } else {
                return nil
            }

        }

        public func hasCommonParent(with language: Language) -> Bool {
            self.parent == language.parent
        }

        /// Returns if `self` and the specified `language` are equal after expanding missing components
        /// For example, `en`, `en-Latn`, `en-US`, and `en-Latn-US` are equivalent
        public func isEquivalent(to language: Language) -> Bool {
            return self.maximalIdentifier == language.maximalIdentifier
        }

        // MARK: - identifiers

        /// Returns a BCP-47 identifier in a minimalist form. Script and region may be omitted. For example, "zh-TW", "en"
        public var minimalIdentifier : String {
            let componentsIdentifier = components.identifier

            let localeIDWithLikelySubtags = _withFixedCharBuffer { buffer, size, status in
                return uloc_minimizeSubtags(componentsIdentifier, buffer, size, &status)
            }

            guard let localeIDWithLikelySubtags else { return componentsIdentifier }

            let tag = _withFixedCharBuffer { buffer, Size, status in
                return uloc_toLanguageTag(localeIDWithLikelySubtags, buffer, Size, UBool.false, &status)
            }

            guard let tag else { return componentsIdentifier }

            return tag
        }

        /// Returns a BCP-47 identifier that always includes the script: "zh-Hant-TW", "en-Latn-US"
        public var maximalIdentifier : String {
            let id = components.identifier
            let localeIDWithLikelySubtags = _withFixedCharBuffer { buffer, size, status in
                return uloc_addLikelySubtags(id, buffer, size, &status)
            }

            guard let localeIDWithLikelySubtags else { return id }

            let tag = _withFixedCharBuffer { buffer, size, status in
                return uloc_toLanguageTag(localeIDWithLikelySubtags, buffer, size, UBool.false, &status)
            }

            guard let tag else { return id }

            return tag
        }

        // MARK: -

        /// The language code of the language. Returns nil if it cannot be determined
        public var languageCode: LanguageCode? {
            var result: LanguageCode?
            if let lang = components.languageCode {
                result = lang
            } else {
                result = _withFixedCharBuffer { buffer, size, status in
                    uloc_getLanguage(components.identifier, buffer, size, &status)
                }.map { LanguageCode($0) }
            }
            return result
        }

        /// The script of the language. Returns nil if it cannot be determined
        public var script: Script? {
            var result: Script?
            if let script = components.script {
                result = script
            } else {
                result = _withFixedCharBuffer { buffer, size, status in
                    // Use `maximalIdentifier` to ensure that script code is present in the identifier. 
                    uloc_getScript(maximalIdentifier, buffer, size, &status)
                }.map { Script($0) }
            }
            return result
        }

        /// The region of the language. Returns nil if it cannot be determined
        public var region: Region? {
            var result: Region?
            if let script = components.region {
                result = script
            } else {
                result = _withFixedCharBuffer { buffer, size, status in
                    uloc_getCountry(components.identifier, buffer, size, &status)
                }.map { Region($0) }
            }
            return result
        }

        /// Returns a list of system languages, includes the languages of all product localization for the current platform
        public static var systemLanguages: [Language] {
#if FOUNDATION_FRAMEWORK
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

extension Locale.LanguageDirection {
    init(layoutType: ULayoutType) {
        switch layoutType {
        case ULOC_LAYOUT_UNKNOWN:
            self = .unknown
        case ULOC_LAYOUT_LTR:
            self = .leftToRight
        case ULOC_LAYOUT_RTL:
            self = .rightToLeft
        case ULOC_LAYOUT_TTB:
            self = .topToBottom
        case ULOC_LAYOUT_BTT:
            self = .bottomToTop
        default:
            self = .unknown
        }
    }
}
