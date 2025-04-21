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
// Outlines the options available to format ProgressReporter
@available(FoundationPreview 6.2, *)
extension ProgressReporter {
    
    public struct FormatStyle: Sendable, Codable, Equatable, Hashable {

        // Outlines the options available to format ProgressReporter
        internal struct Option: Sendable, Codable, Hashable, Equatable {
            
            #if FOUNDATION_FRAMEWORK
            /// Option specifying`fractionCompleted`.
            ///
            /// For example, 20% completed.
            /// - Parameter style: A `FloatingPointFormatStyle<Double>.Percent` instance that should be used to format `fractionCompleted`.
            /// - Returns: A `LocalizedStringResource` for formatted `fractionCompleted`.
            internal static func fractionCompleted(format style: Foundation.FloatingPointFormatStyle<Double>.Percent = Foundation.FloatingPointFormatStyle<Double>.Percent()
            ) -> Option {
                return Option(.fractionCompleted(style))
            }
            
            /// Option specifying `completedCount` / `totalCount`.
            ///
            /// For example, 5 of 10.
            /// - Parameter style: An `IntegerFormatStyle<Int>` instance that should be used to format `completedCount` and `totalCount`.
            /// - Returns: A `LocalizedStringResource` for formatted `completedCount` / `totalCount`.
            internal static func count(format style: Foundation.IntegerFormatStyle<Int> = Foundation.IntegerFormatStyle<Int>()
            ) -> Option {
                return Option(.count(style))
            }
            #else
            /// Option specifying`fractionCompleted`.
            ///
            /// For example, 20% completed.
            /// - Parameter style: A `FloatingPointFormatStyle<Double>.Percent` instance that should be used to format `fractionCompleted`.
            /// - Returns: A `LocalizedStringResource` for formatted `fractionCompleted`.
            internal static func fractionCompleted(format style: FoundationInternationalization.FloatingPointFormatStyle<Double>.Percent = FoundationInternationalization.FloatingPointFormatStyle<Double>.Percent()
            ) -> Option {
                return Option(.fractionCompleted(style))
            }
            
            /// Option specifying `completedCount` / `totalCount`.
            ///
            /// For example, 5 of 10.
            /// - Parameter style: An `IntegerFormatStyle<Int>` instance that should be used to format `completedCount` and `totalCount`.
            /// - Returns: A `LocalizedStringResource` for formatted `completedCount` / `totalCount`.
            internal static func count(format style: FoundationInternationalization.IntegerFormatStyle<Int> = FoundationInternationalization.IntegerFormatStyle<Int>()
            ) -> Option {
                return Option(.count(style))
            }
            #endif // FOUNDATION_FRAMEWORK
            
            
            fileprivate enum RawOption: Codable, Hashable, Equatable {
                case count(IntegerFormatStyle<Int>)
                case fractionCompleted(FloatingPointFormatStyle<Double>.Percent)
            }
            
            fileprivate var rawOption: RawOption
        
            private init(_ rawOption: RawOption) {
                self.rawOption = rawOption
            }
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
extension ProgressReporter.FormatStyle: FormatStyle {
    
    public func locale(_ locale: Locale) -> ProgressReporter.FormatStyle {
        .init(self.option, locale: locale)
    }
    
    public func format(_ reporter: ProgressReporter) -> String {
        switch self.option.rawOption {
        case .count(let countStyle):
            let count = reporter.withProperties { p in
                return (p.completedCount, p.totalCount)
            }
            let countLSR = LocalizedStringResource("\(count.0, format: countStyle) of \(count.1 ?? 0, format: countStyle)", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            return String(localized: countLSR)
            
        case .fractionCompleted(let fractionStyle):
            let fractionLSR = LocalizedStringResource("\(reporter.fractionCompleted, format: fractionStyle) completed", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            return String(localized: fractionLSR)
        }
    }
}

@available(FoundationPreview 6.2, *)
// Make access easier to format ProgressReporter
extension ProgressReporter {
    
#if FOUNDATION_FRAMEWORK
    public func formatted<F: Foundation.FormatStyle>(_ style: F) -> F.FormatOutput where F.FormatInput == ProgressReporter {
        style.format(self)
    }
#else
    public func formatted<F: FoundationEssentials.FormatStyle>(_ style: F) -> F.FormatOutput where F.FormatInput == ProgressReporter {
        style.format(self)
    }
#endif // FOUNDATION_FRAMEWORK
    

    public func formatted() -> String {
        self.formatted(.fractionCompleted())
    }
    
}

@available(FoundationPreview 6.2, *)
extension FormatStyle where Self == ProgressReporter.FormatStyle {
    
#if FOUNDATION_FRAMEWORK
    public static func fractionCompleted(
        format: Foundation.FloatingPointFormatStyle<Double>.Percent = Foundation.FloatingPointFormatStyle<Double>.Percent()
    ) -> Self {
        .init(.fractionCompleted(format: format))
    }

    public static func count(
        format: Foundation.IntegerFormatStyle<Int> = Foundation.IntegerFormatStyle<Int>()
    ) -> Self {
        .init(.count(format: format))
    }
#else
    public static func fractionCompleted(
        format: FoundationInternationalization.FloatingPointFormatStyle<Double>.Percent = FoundationInternationalization.FloatingPointFormatStyle<Double>.Percent()
    ) -> Self {
        .init(.fractionCompleted(format: format))
    }

    public static func count(
        format: FoundationInternationalization.IntegerFormatStyle<Int> = FoundationInternationalization.IntegerFormatStyle<Int>()
    ) -> Self {
        .init(.count(format: format))
    }
#endif
    

}
