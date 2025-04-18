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
@_spi(Progress)
@available(FoundationPreview 6.2, *)
extension ProgressReporter {
    //TODO: rdar://149092406 Manual Codable Conformance
    public struct FileFormatStyle: Sendable, Codable, Equatable, Hashable {
        
        internal struct Option: Sendable, Codable, Equatable, Hashable {
            
            internal static var file: Option { Option(.file) }
            
            fileprivate enum RawOption: Codable, Equatable, Hashable {
                case file
            }
            
            fileprivate var rawOption: RawOption
            
            private init(
                _ rawOption: RawOption,
            ) {
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


@_spi(Progress)
@available(FoundationPreview 6.2, *)
extension ProgressReporter.FileFormatStyle: FormatStyle {
    
    public func locale(_ locale: Locale) -> ProgressReporter.FileFormatStyle {
        .init(self.option, locale: locale)
    }
    
    public func format(_ reporter: ProgressReporter) -> String {
        switch self.option.rawOption {
      
        case .file:
            var fileCountLSR: LocalizedStringResource?
            var byteCountLSR: LocalizedStringResource?
            var throughputLSR: LocalizedStringResource?
            var timeRemainingLSR: LocalizedStringResource?
            
            let properties = reporter.withProperties(\.self)
            
            if let totalFileCount = properties.totalFileCount {
                let completedFileCount = properties.completedFileCount ?? 0
                fileCountLSR = LocalizedStringResource("\(completedFileCount, format: IntegerFormatStyle<Int>()) of \(totalFileCount, format: IntegerFormatStyle<Int>()) files", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            }
            
            if let totalByteCount = properties.totalByteCount {
                let completedByteCount = properties.completedByteCount ?? 0
                byteCountLSR = LocalizedStringResource("\(completedByteCount, format: ByteCountFormatStyle()) of \(totalByteCount, format: ByteCountFormatStyle())", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            }
            
            if let throughput = properties.throughput {
                throughputLSR = LocalizedStringResource("\(throughput, format: ByteCountFormatStyle())/s", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            }
            
            if let timeRemaining = properties.estimatedTimeRemaining {
                timeRemainingLSR = LocalizedStringResource("\(timeRemaining, format: Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)) remaining", locale: self.locale, bundle: .forClass(ProgressReporter.self))
            }
            
            return """
            \(String(localized: fileCountLSR ?? "")) 
            \(String(localized: byteCountLSR ?? ""))
            \(String(localized: throughputLSR ?? "")) 
            \(String(localized: timeRemainingLSR ?? ""))
            """
        }
    }
}

@_spi(Progress)
@available(FoundationPreview 6.2, *)
// Make access easier to format ProgressReporter
extension ProgressReporter {
    public func formatted(_ style: ProgressReporter.FileFormatStyle) -> String {
        style.format(self)
    }
}

@_spi(Progress)
@available(FoundationPreview 6.2, *)
extension FormatStyle where Self == ProgressReporter.FileFormatStyle {
    public static var file: Self {
        .init(.file)
    }
}
