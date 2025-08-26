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

internal import _FoundationICU

extension AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute.Symbol {
    init?(unumberFormatField: UNumberFormatFields) {
        switch unumberFormatField {
        case .decimalSeparator:
            self = .decimalSeparator
        case .groupingSeparator:
            self = .groupingSeparator
        case .currencySymbol:
            self = .currency
        case .percentSymbol:
            self = .percent
        case .sign:
            self = .sign
        default:
            return nil
        }
    }
}

extension AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute.NumberPart {
    init?(unumberFormatField: UNumberFormatFields) {
        switch unumberFormatField {
        case .integer:
            self = .integer
        case .fraction:
            self = .fraction
        default:
            return nil
        }
    }
}

extension AttributeScopes.FoundationAttributes.MeasurementAttribute.Component {
    init?(unumberFormatField: UNumberFormatFields) {
        switch unumberFormatField {
        case .integer:
            self = .value
        case .fraction:
            self = .value
        case .decimalSeparator:
            self = .value
        case .groupingSeparator:
            self = .value
        case .sign:
            self = .value
        case .currencySymbol:
            return nil
        case .percentSymbol:
            return nil
        case .measureUnit:
            self = .unit
        default:
            return nil
        }
    }
}
