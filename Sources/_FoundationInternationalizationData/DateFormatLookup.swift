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

// Keep the slot orders and sub-blocks in this file in sync with utils/build-date-format-data-impl.swift.

extension _DateFormatData : LocaleDataTable {}

// MARK: - Locales

/// Each group's first sub-block in a row. Groups have one sub-block per context and width, in slot order.
package enum DateFormatDataGroup : Int {
    case months = 0, weekdays = 6, quarters = 14, eras = 20, dayPeriods = 23, gmt = 26, capitalization = 27
}

/// The contextTransforms usages for date fields, in table order.
package enum DateFormatCapitalizationUsage : Int {
    case monthFormat, monthStandalone, monthNarrow, dayFormat, dayStandalone, dayNarrow, eraWide, eraAbbreviated, eraNarrow
    /// Output that starts with fixed text, an Apple addition.
    case dateOtherBeginning
}

/// The name contexts CLDR stores.
package enum DateFormatNameContext : Int {
    case format, standalone
}

/// Name widths, in table order. Weekdays also have `short`.
package enum DateFormatNameWidth : Int {
    case abbreviated, narrow, wide, short
}

/// A locale's date-format data.
package struct DateFormatLocale : Sendable {
    /// The locale's row's first index in `rows`.
    let row: Int

    /// Resolves a locale identifier, ignoring keywords, to the nearest locale in the tables.
    ///
    /// Where the identifier's language has no data, this uses the tables' built-in fallback locale if they have one,
    /// else root.
    package init(_ identifier: DataLocaleIdentifier) {
        self.init(localeIndex: _LocaleIDData.localeIndex(forBaseName: identifier.baseName))
    }

    /// `localeIndex` comes from `_LocaleIDData.localeIndex(forBaseName:)`.
    package init(localeIndex: Int) {
        row = Int(_DateFormatData.localeRows[localeIndex]) * _DateFormatData.rowWidth
    }

    /// The string in `slot` of the locale's `subBlock`th sub-block for `group`.
    package func string(_ group: DateFormatDataGroup, _ subBlock: Int, _ slot: Int) -> DataString<_DateFormatData> {
        let start = Int(_DateFormatData.rows[row + group.rawValue + subBlock])
        return DataString(entry: _DateFormatData.names[start + slot])
    }

    // MARK: Names

    /// `month` is 1-based.
    package func month(_ month: Int, context: DateFormatNameContext, width: DateFormatNameWidth) -> DataString<_DateFormatData> {
        string(.months, context.rawValue * 3 + width.rawValue, month - 1)
    }

    /// `weekday` is 1-based, Sunday first.
    package func weekday(_ weekday: Int, context: DateFormatNameContext, width: DateFormatNameWidth) -> DataString<_DateFormatData> {
        // The table orders weekday widths abbreviated, narrow, short, wide.
        let widthSlot = switch width {
        case .abbreviated: 0
        case .narrow: 1
        case .short: 2
        case .wide: 3
        }
        return string(.weekdays, context.rawValue * 4 + widthSlot, weekday - 1)
    }

    /// `quarter` is 1-based.
    package func quarter(_ quarter: Int, context: DateFormatNameContext, width: DateFormatNameWidth) -> DataString<_DateFormatData> {
        string(.quarters, context.rawValue * 3 + width.rawValue, quarter - 1)
    }

    package func era(_ era: Int, width: DateFormatNameWidth) -> DataString<_DateFormatData> {
        string(.eras, width.rawValue, era)
    }

    /// `period` is 0 for AM, 1 for PM, 2 for noon.
    package func dayPeriod(_ period: Int, width: DateFormatNameWidth) -> DataString<_DateFormatData> {
        string(.dayPeriods, width.rawValue, period)
    }

    /// The localized GMT pattern, such as `GMT{0}`.
    package var gmtFormat: DataString<_DateFormatData> { string(.gmt, 0, 0) }

    /// The positive and negative offset patterns, such as `+HH:mm;-HH:mm`.
    package var hourFormat: DataString<_DateFormatData> { string(.gmt, 0, 1) }

    /// Returns the Chinese day numeral for `day`, 1 through 31, for `numbers=hanidays`.
    package static func hanidaysDay(_ day: Int) -> DataString<_DateFormatData> {
        DataString(entry: _DateFormatData.hanidaysDays[day - 1])
    }

    /// Whether to titlecase a field with this usage at the start of a UI list item or menu item, or when it stands alone.
    package func capitalizes(_ usage: DateFormatCapitalizationUsage, forListItem: Bool) -> Bool {
        // Two flags, for list items then standalone use, as "0" or "1".
        let flags = string(.capitalization, 0, usage.rawValue)
        guard !flags.isEmpty else { return false }
        return UInt8(truncatingIfNeeded: flags.entry >> (forListItem ? 8 : 16)) == UInt8(ascii: "1")
    }
}
