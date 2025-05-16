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
extension ProgressManager {
    //TODO: rdar://149092406 Manual Codable Conformance
    public struct FileFormatStyle: Sendable, Codable, Equatable, Hashable {
        
        internal struct Option: Sendable, Codable, Equatable, Hashable {

            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                self.rawOption = try container.decode(RawOption.self)
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawOption)
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
extension ProgressManager.FileFormatStyle: FormatStyle {
    
    public func locale(_ locale: Locale) -> ProgressManager.FileFormatStyle {
        .init(self.option, locale: locale)
    }
    
    public func format(_ manager: ProgressManager) -> String {
        switch self.option.rawOption {
      
        case .file:
            #if FOUNDATION_FRAMEWORK
            var fileCountLSR: LocalizedStringResource?
            var byteCountLSR: LocalizedStringResource?
            var throughputLSR: LocalizedStringResource?
            var timeRemainingLSR: LocalizedStringResource?
            
            let properties = manager.withProperties(\.self)
            
            fileCountLSR = LocalizedStringResource("\(properties.completedFileCount, format: IntegerFormatStyle<Int>()) of \(properties.totalFileCount, format: IntegerFormatStyle<Int>()) files", locale: self.locale, bundle: .forClass(ProgressManager.self))
            
            
            byteCountLSR = LocalizedStringResource("\(properties.completedByteCount, format: ByteCountFormatStyle()) of \(properties.totalByteCount, format: ByteCountFormatStyle())", locale: self.locale, bundle: .forClass(ProgressManager.self))
            
            
            throughputLSR = LocalizedStringResource("\(properties.throughput, format: ByteCountFormatStyle())/s", locale: self.locale, bundle: .forClass(ProgressManager.self))
            
            timeRemainingLSR = LocalizedStringResource("\(properties.estimatedTimeRemaining, format: Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)) remaining", locale: self.locale, bundle: .forClass(ProgressManager.self))
            
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
                        
            let properties = manager.withProperties(\.self)
            

            fileCountString = "\(properties.completedFileCount.formatted(IntegerFormatStyle<Int>(locale: self.locale))) / \(properties.totalFileCount.formatted(IntegerFormatStyle<Int>(locale: self.locale)))"
            
  
            byteCountString = "\(properties.completedByteCount.formatted(ByteCountFormatStyle(locale: self.locale))) / \(properties.totalByteCount.formatted(ByteCountFormatStyle(locale: self.locale)))"
                
            throughputString = "\(properties.throughput.formatted(ByteCountFormatStyle(locale: self.locale)))/s"
        
            var formatStyle = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)
            formatStyle.locale = self.locale
            timeRemainingString = "\(properties.estimatedTimeRemaining.formatted(formatStyle)) remaining"
        
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
// Make access easier to format ProgressManager
extension ProgressManager {
    public func formatted(_ style: ProgressManager.FileFormatStyle) -> String {
        style.format(self)
    }
}

@available(FoundationPreview 6.2, *)
extension FormatStyle where Self == ProgressManager.FileFormatStyle {
    public static var file: Self {
        .init(.file)
    }
}
