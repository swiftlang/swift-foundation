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

@available(FoundationPreview 6.2, *)
extension ProgressReporter {
    //TODO: rdar://149092406 Manual Codable Conformance
    public struct FileFormatStyle: Sendable, Codable, Equatable, Hashable {
        
        internal struct Option: Sendable, Codable, Equatable, Hashable {
            
            enum CodingKeys: String, CodingKey {
                case rawOption
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                rawOption = try container.decode(RawOption.self, forKey: .rawOption)
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(rawOption, forKey: .rawOption)
            }
            
            internal static var file: Option { Option(.file) }
            
            fileprivate enum RawOption: Codable, Equatable, Hashable {
                case file
            }
            
            fileprivate var rawOption: RawOption
            
            private init(_ rawOption: RawOption) {
                self.rawOption = rawOption
            }
        }
        
        struct CodableRepresentation: Codable {
            let locale: Locale
            let includeFileDescription: Bool
        }
        
        var codableRepresentation: CodableRepresentation {
            .init(locale: self.locale, includeFileDescription: option.rawOption == .file)
        }

        public init(from decoder: any Decoder) throws {
            //TODO: Fix this later, codableRepresentation is not settable
            let container = try decoder.singleValueContainer()
            let rep = try container.decode(CodableRepresentation.self)
            locale = rep.locale
            option = .file
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
extension ProgressReporter.FileFormatStyle: FormatStyle {
    
    public func locale(_ locale: Locale) -> ProgressReporter.FileFormatStyle {
        .init(self.option, locale: locale)
    }
    
    public func format(_ reporter: ProgressReporter) -> String {
        switch self.option.rawOption {
      
        case .file:
            #if FOUNDATION_FRAMEWORK
            var fileCountLSR: LocalizedStringResource?
            var byteCountLSR: LocalizedStringResource?
            var throughputLSR: LocalizedStringResource?
            var timeRemainingLSR: LocalizedStringResource?
            
            let properties = reporter.withProperties(\.self)
            
            fileCountLSR = LocalizedStringResource("\(properties.completedFileCount, format: IntegerFormatStyle<Int>()) of \(properties.totalFileCount, format: IntegerFormatStyle<Int>()) files", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            
            
            byteCountLSR = LocalizedStringResource("\(properties.completedByteCount, format: ByteCountFormatStyle()) of \(properties.totalByteCount, format: ByteCountFormatStyle())", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            
            
            throughputLSR = LocalizedStringResource("\(properties.throughput, format: ByteCountFormatStyle())/s", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            
            timeRemainingLSR = LocalizedStringResource("\(properties.estimatedTimeRemaining, format: Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)) remaining", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            
            return """
            \(String(localized: fileCountLSR ?? "")) 
            \(String(localized: byteCountLSR ?? ""))
            \(String(localized: throughputLSR ?? "")) 
            \(String(localized: timeRemainingLSR ?? ""))
            """
            #else
            
            var fileCountString: String?
            var byteCountString: String?
            var throughputString: String?
            var timeRemainingString: String?
                        
            let properties = reporter.withProperties(\.self)
            
            if let totalFileCount = properties.totalFileCount {
                let completedFileCount = properties.completedFileCount ?? 0
                fileCountString = "\(completedFileCount.formatted(IntegerFormatStyle<Int>(locale: self.locale))) / \(totalFileCount.formatted(IntegerFormatStyle<Int>(locale: self.locale)))"
            }
            
            if let totalByteCount = properties.totalByteCount {
                let completedByteCount = properties.completedByteCount ?? 0
                byteCountString = "\(completedByteCount.formatted(ByteCountFormatStyle(locale: self.locale))) / \(totalByteCount.formatted(ByteCountFormatStyle(locale: self.locale)))"
            }
            
            if let throughput = properties.throughput {
                throughputString = "\(throughput.formatted(ByteCountFormatStyle(locale: self.locale)))/s"
            }
            
            if let timeRemaining = properties.estimatedTimeRemaining {
                var formatStyle = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)
                formatStyle.locale = self.locale
                timeRemainingString = "\(timeRemaining.formatted(formatStyle)) remaining"
            }
            
            return """
            \(fileCountString ?? "")
            \(byteCountString ?? "")
            \(throughputString ?? "")
            \(timeRemainingString ?? "")
            """
            #endif
        }
    }
}

@available(FoundationPreview 6.2, *)
// Make access easier to format ProgressReporter
extension ProgressReporter {
    public func formatted(_ style: ProgressReporter.FileFormatStyle) -> String {
        style.format(self)
    }
}

@available(FoundationPreview 6.2, *)
extension FormatStyle where Self == ProgressReporter.FileFormatStyle {
    public static var file: Self {
        .init(.file)
    }
}
