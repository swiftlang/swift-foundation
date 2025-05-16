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
#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
// Outlines the options available to format ProgressManager
@available(FoundationPreview 6.2, *)
extension ProgressManager {
    
    public struct FormatStyle: Sendable, Codable, Equatable, Hashable {

        // Outlines the options available to format ProgressManager
        internal struct Option: Sendable, Codable, Hashable, Equatable {
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                rawOption = try container.decode(RawOption.self)
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawOption)
            }
            
            /// Option specifying `fractionCompleted`.
            ///
            /// For example, 20% completed.
            /// - Parameter style: A `FloatingPointFormatStyle<Double>.Percent` instance that should be used to format `fractionCompleted`.
            /// - Returns: A `LocalizedStringResource` for formatted `fractionCompleted`.
            internal static func fractionCompleted(format style: FloatingPointFormatStyle<Double>.Percent = FloatingPointFormatStyle<Double>.Percent()
            ) -> Option {
                return Option(.fractionCompleted(style))
            }
            
            /// Option specifying `completedCount` / `totalCount`.
            ///
            /// For example, 5 of 10.
            /// - Parameter style: An `IntegerFormatStyle<Int>` instance that should be used to format `completedCount` and `totalCount`.
            /// - Returns: A `LocalizedStringResource` for formatted `completedCount` / `totalCount`.
            internal static func count(format style: IntegerFormatStyle<Int> = IntegerFormatStyle<Int>()
            ) -> Option {
                return Option(.count(style))
            }

            fileprivate enum RawOption: Codable, Hashable, Equatable {
                case count(IntegerFormatStyle<Int>)
                case fractionCompleted(FloatingPointFormatStyle<Double>.Percent)
            }
            
            fileprivate var rawOption: RawOption
        
            private init(_ rawOption: RawOption) {
                self.rawOption = rawOption
            }
        }
        
        struct CodableRepresentation: Codable {
            let locale: Locale
            let option: Option
        }
        
        var codableRepresentation: CodableRepresentation {
            .init(locale: self.locale, option: self.option)
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(CodableRepresentation.self)
            self.locale = rawValue.locale
            self.option = rawValue.option
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(codableRepresentation)
        }

        public var locale: Locale
        let option: Option
        
        internal init(_ option: Option, locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
            self.option = option
        }
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressManager.FormatStyle: FormatStyle {
    
    public func locale(_ locale: Locale) -> ProgressManager.FormatStyle {
        .init(self.option, locale: locale)
    }
    
    public func format(_ manager: ProgressManager) -> String {
        switch self.option.rawOption {
        case .count(let countStyle):
            let count = manager.withProperties { p in
                return (p.completedCount, p.totalCount)
            }
            #if FOUNDATION_FRAMEWORK
            let countLSR = LocalizedStringResource("\(count.0, format: countStyle) of \(count.1 ?? 0, format: countStyle)", locale: self.locale, bundle: .forClass(ProgressManager.self))
            return String(localized: countLSR)
            #else
            return "\(count.0.formatted(countStyle.locale(self.locale))) / \((count.1 ?? 0).formatted(countStyle.locale(self.locale)))"
            #endif
            
        case .fractionCompleted(let fractionStyle):
            #if FOUNDATION_FRAMEWORK
            let fractionLSR = LocalizedStringResource("\(manager.fractionCompleted, format: fractionStyle) completed", locale: self.locale, bundle: .forClass(ProgressManager.self))
            return String(localized: fractionLSR)
            #else
            return "\(manager.fractionCompleted.formatted(fractionStyle.locale(self.locale)))"
            #endif
        }
    }
}

@available(FoundationPreview 6.2, *)
// Make access easier to format ProgressManager
extension ProgressManager {
    
#if FOUNDATION_FRAMEWORK
    public func formatted<F: Foundation.FormatStyle>(_ style: F) -> F.FormatOutput where F.FormatInput == ProgressManager {
        style.format(self)
    }
#else
    public func formatted<F: FoundationEssentials.FormatStyle>(_ style: F) -> F.FormatOutput where F.FormatInput == ProgressManager {
        style.format(self)
    }
#endif // FOUNDATION_FRAMEWORK
    
    public func formatted() -> String {
        self.formatted(.fractionCompleted())
    }
    
}

@available(FoundationPreview 6.2, *)
extension FormatStyle where Self == ProgressManager.FormatStyle {
    
    public static func fractionCompleted(
        format: FloatingPointFormatStyle<Double>.Percent = FloatingPointFormatStyle<Double>.Percent()
    ) -> Self {
        .init(.fractionCompleted(format: format))
    }

    public static func count(
        format: IntegerFormatStyle<Int> = IntegerFormatStyle<Int>()
    ) -> Self {
        .init(.count(format: format))
    }
}
