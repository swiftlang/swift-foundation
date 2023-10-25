//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class ICUListFormatter {
    let uformatter: OpaquePointer

    internal static let cache = FormatterCache<AnyHashable, ICUListFormatter>()

    static let uListFormatterTypes: [UListFormatterType] = [ .and, .or, .units ]
    static let uListFormatterWidths: [UListFormatterWidth] = [ .wide, .short, .narrow ]

    private init(locale: Locale, type: UListFormatterType, width: UListFormatterWidth) {
        var status = U_ZERO_ERROR
        let result = ulistfmt_openForType(locale.identifier, type, width, &status)
        guard let result, status.isSuccess else {
            preconditionFailure("Unable to create list formatter: \(status.rawValue)")
        }
        uformatter = result
    }

    deinit {
        ulistfmt_close(uformatter)
    }

    func format(strings: [String]) -> String {
        var ucharStringPointers: [UnsafePointer<UChar>?] = []
        var ucharStringLengths: [Int32] = []

        ucharStringPointers.reserveCapacity(strings.count)
        ucharStringLengths.reserveCapacity(strings.count)

        for string in strings {
            let uchars = Array(string.utf16)
            let ucharsPointer = UnsafeMutablePointer<UChar>.allocate(capacity: uchars.count)
            ucharsPointer.initialize(from: uchars, count: uchars.count)
            ucharStringPointers.append(UnsafePointer(ucharsPointer))
            ucharStringLengths.append(Int32(uchars.count))
        }

        let result = _withResizingUCharBuffer { buffer, size, status in
            ulistfmt_format(uformatter, ucharStringPointers, ucharStringLengths, Int32(strings.count), buffer, size, &status)
        }

        for pointer in ucharStringPointers {
            pointer?.deallocate()
        }

        return result ?? ""
    }

    internal static func formatterCreateIfNeeded<Style, Base>(format: ListFormatStyle<Style, Base>) -> ICUListFormatter {
        let formatter = Self.cache.formatter(for: format) {
            ICUListFormatter(locale: format.locale, type: uListFormatterTypes[format.listType.rawValue], width: uListFormatterWidths[format.width.rawValue])
        }
        return formatter
    }

}
